extends TestCase
## Stage 17 of the battle simulation: how battles end, and the outcome summary.

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.NOVICE)


func _sim(opponent_id: String = "pip", seed_value: int = 9) -> BattleSimulator:
	return BattleSimulator.create(BattleState.for_fight(_trial(opponent_id), champion, seed_value))


func _trial(opponent_id: String) -> TrialData:
	for trial: TrialData in Content.list("trials"):
		if trial.opponent_id == opponent_id:
			return trial
	return null


## A battle where nobody acts, cut short at `ticks`.
func _idle(ticks: int) -> BattleSimulator:
	var sim := _sim()
	for phase_name: String in ["decision", "action", "contact", "damage", "force", "movement", "stamina"]:
		sim.use_phase(SimulationPhase.new(phase_name))
	sim.max_ticks = ticks
	return sim


func test_time_limit_is_decided_on_health() -> void:
	var sim := _idle(10)
	sim.state.combatants[1].health *= 0.6
	sim.run()
	check_eq(sim.state.winner_team, 0, "more health left wins the decision")
	check_eq(sim.battle_log.events_of("battle_end")[0]["reason"], "decision")
	check_eq(sim.outcome().reason, "decision")


func test_too_close_to_call_is_a_draw() -> void:
	var sim := _idle(10)
	sim.state.combatants[0].health *= 0.5
	sim.state.combatants[1].health *= 0.5
	sim.run()
	check_eq(sim.state.winner_team, -1)
	check_eq(sim.outcome().reason, "draw")
	check(not sim.outcome().player_won())


func test_damage_breaks_a_near_tie() -> void:
	var state := _sim().state
	var battle_log := BattleLog.begin(state, 30)
	state.combatants[0].health = state.combatants[0].max_health * 0.5
	state.combatants[1].health = state.combatants[1].max_health * 0.51
	battle_log.events.append({"type": "damage", "actor": 0, "target": 1, "amount": 200.0})
	battle_log.events.append({"type": "damage", "actor": 1, "target": 0, "amount": 80.0})
	check_eq(VictoryRules.decide(state, battle_log), 0, "the busier fighter takes a near tie")


func test_double_knockout_is_a_draw() -> void:
	var sim := _idle(100)
	sim.state.combatants[0].health = 0.0
	sim.state.combatants[1].health = 0.0
	sim.step()
	check(sim.state.finished)
	check_eq(sim.state.winner_team, -1)
	check_eq(sim.battle_log.events_of("battle_end")[0]["reason"], "draw")


func test_outcome_sums_up_the_fight() -> void:
	var sim := _sim("rook", 21)
	sim.run()
	var outcome := sim.outcome()
	check_eq(outcome.reason, "knockout")
	check_eq(outcome.winner_team, sim.state.winner_team)
	var me := outcome.side(0)
	var rook := outcome.side(1)
	check_near(me["damage_dealt"], rook["damage_taken"], 0.5, "what one deals the other takes")
	check_near(rook["damage_dealt"], me["damage_taken"], 0.5)
	var loser := me if not outcome.player_won() else rook
	check(loser["knocked_out"], "the loser was knocked out")
	check_eq(loser["lowest_health_ratio"], 0.0)
	check_eq(me["hits_landed"], _count(sim, "damage", 0, "hit"), "landed blows match the log")
	for key: String in BattleOutcome.TALLIES:
		check(float(me[key]) >= 0.0 and float(rook[key]) >= 0.0, key + " is a count")
	check(outcome.duration > 1.0)
	check_eq(outcome.to_dict()["fighters"].size(), 2)


func test_capability_shows_in_the_outcome() -> void:
	var weak := _sim("marla", 3)
	weak.run()
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.SKILLED)
	for target in ["skill:block", "skill:dodge", "skill:timing", "skill:attack"]:
		champion.skills.set_rank(target, GameEnums.Rank.SKILLED)
	for stat in ["attack", "defense", "endurance", "health"]:
		champion.trained[stat] = 12.0
	var strong := _sim("marla", 3)
	strong.run()
	check(strong.outcome().side(0)["damage_dealt"] > weak.outcome().side(0)["damage_dealt"], "a developed champion does more")
	check(strong.outcome().side(0)["lowest_health_ratio"] >= weak.outcome().side(0)["lowest_health_ratio"])


static func _count(sim: BattleSimulator, type: String, actor: int, outcome: String) -> int:
	var count := 0
	for event in sim.battle_log.events:
		if event["type"] == type and event["actor"] == actor and event.get("outcome", "") == outcome \
				and event.get("kind", "") != "burn":
			count += 1
	return count
