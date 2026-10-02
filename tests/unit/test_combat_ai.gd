extends TestCase
## Stage 16 of the battle simulation: the decision layer. Fighters choose
## from what they see and what they are; the build changes how they fight
## and skill changes how well.

const A := CombatantState.Action
const P := CombatantState.Phase

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.NOVICE)


func _spec(weapon_id: String = "sword_training", ranks: Dictionary = {}, experience: int = 0) -> CombatantSpec:
	var spec := CombatantSpec.from_champion(champion)
	spec.weapon = Content.weapon(weapon_id)
	spec.armor = Content.armor("armor_light")
	for target: String in ranks:
		spec.skills[target] = ranks[target]
	spec.battle_experience = experience
	spec.refresh()
	spec.tendencies = CombatStyle.tendencies_for(spec)
	return spec


func _fight(player: CombatantSpec, opponent: CombatantSpec, seed_value: int) -> BattleSimulator:
	var players: Array[CombatantSpec] = [player]
	var opponents: Array[CombatantSpec] = [opponent]
	var sim := BattleSimulator.create(BattleState.create(Content.arena("meadow_ring"), players, opponents, seed_value))
	sim.run()
	return sim


func _rook() -> CombatantSpec:
	return CombatantSpec.from_opponent(Content.opponent("rook"))


func test_ai_battles_are_decided_and_deterministic() -> void:
	for opponent_id in ["pip", "rook", "juniper", "marla"]:
		var sim := _fight(_spec(), CombatantSpec.from_opponent(Content.opponent(opponent_id)), 77)
		check(sim.state.winner_team >= 0, "%s: decided by knockout, not the clock" % opponent_id)
	var a := _fight(_spec(), _rook(), 5)
	var b := _fight(_spec(), _rook(), 5)
	check_eq(JSON.stringify(a.battle_log.events), JSON.stringify(b.battle_log.events), "same inputs, same battle")


func test_capability_decides_more_than_luck() -> void:
	var fresh := 0
	var trained := 0
	var skilled := {"weapon:sword": GameEnums.Rank.SKILLED, "skill:block": GameEnums.Rank.SKILLED,
			"skill:dodge": GameEnums.Rank.SKILLED, "skill:timing": GameEnums.Rank.SKILLED, "skill:attack": GameEnums.Rank.SKILLED}
	var strong := _spec("sword_training", skilled, 12)
	for stat in ["attack", "defense", "endurance", "health"]:
		strong.stats[stat] = strong.get_stat(stat) + 12.0
	strong.refresh()
	for seed_value in 6:
		var marla := CombatantSpec.from_opponent(Content.opponent("marla"))
		if _fight(_spec(), marla, 300 + seed_value).state.winner_team == 0:
			fresh += 1
		if _fight(strong, CombatantSpec.from_opponent(Content.opponent("marla")), 300 + seed_value).state.winner_team == 0:
			trained += 1
	check(trained >= fresh + 3, "development changes the outcome (%d vs %d of 6)" % [trained, fresh])


func test_reactions_come_from_skill_and_experience() -> void:
	var novice := _spec()
	var veteran := _spec("sword_training", {"skill:timing": GameEnums.Rank.EXPERT}, 60)
	check(DecisionPhase.reaction_time(veteran) < DecisionPhase.reaction_time(novice) - 0.1, "reads blows sooner")
	check(DecisionPhase.timing_error(veteran) < DecisionPhase.timing_error(novice) * 0.5, "times answers better")


func test_threats_are_read_from_the_battle() -> void:
	var players: Array[CombatantSpec] = [_spec()]
	var opponents: Array[CombatantSpec] = [_rook()]
	var state := BattleState.create(Content.arena("meadow_ring"), players, opponents, 1)
	var me := state.combatants[0]
	var rook := state.combatants[1]
	me.position = Vector2(0, 1)
	rook.position = Vector2(0, -0.8)
	rook.facing = Vector2(0, 1)
	check(DecisionPhase.threat_to(state, me).is_empty(), "nothing coming yet")
	rook.action = A.HEAVY
	rook.phase = P.WINDUP
	rook.phase_length = 1.0
	rook.phase_time = 0.4
	var threat := DecisionPhase.threat_to(state, me)
	check_eq(threat["kind"], "heavy")
	check_near(threat["time"], 0.6, 0.001)
	rook.position = Vector2(0, -6)
	check(DecisionPhase.threat_to(state, me).is_empty(), "a swing that cannot reach is no threat")
	state.projectiles.append({"id": 9, "owner": 1, "team": 1, "kind": "cast", "ability": "ember_bolt", "swing": 1,
			"combo": 0, "position": Vector2(0, -4), "direction": Vector2(0, 1), "speed": 10.0, "radius": 0.45, "range_left": 10.0})
	threat = DecisionPhase.threat_to(state, me)
	check_eq(threat["kind"], "projectile")
	check_near(threat["time"], 0.5, 0.001)


func _intent(state: BattleState, index: int) -> Dictionary:
	var phase := DecisionPhase.new()
	var frame := SimFrame.new(1, state.time, 1.0 / 30.0)
	phase.run(state, frame)
	return frame.intents.get(index, {})


func _duel(player: CombatantSpec, opponent: CombatantSpec) -> BattleState:
	var players: Array[CombatantSpec] = [player]
	var opponents: Array[CombatantSpec] = [opponent]
	var state := BattleState.create(Content.arena("meadow_ring"), players, opponents, 3)
	state.combatants[0].position = Vector2(0, 1)
	state.combatants[0].facing = Vector2(0, -1)
	state.combatants[1].position = Vector2(0, -0.6)
	state.combatants[1].facing = Vector2(0, 1)
	return state


func test_openings_are_punished() -> void:
	var state := _duel(_spec(), _rook())
	var rook := state.combatants[1]
	rook.action = A.HEAVY
	rook.phase = P.RECOVERY
	rook.phase_length = 1.0
	rook.phase_time = 0.0
	var intent := _intent(state, 0)
	check(intent.get("action", "") in ["attack", "heavy"], "a recovering hammer is struck at once (%s)" % [intent])
	check_eq(intent["action"], "heavy", "with time for a heavy blow, it takes it")


func test_low_stamina_backs_off() -> void:
	var state := _duel(_spec(), _rook())
	state.combatants[0].stamina = 5.0
	var intent := _intent(state, 0)
	check(not intent.has("action") or intent["action"] == "", "no new attack while spent")
	var away: Vector2 = intent["move"]
	check(away.dot(state.combatants[1].position - state.combatants[0].position) < 0.0, "steps away to recover")


func test_far_targets_are_approached_or_shot() -> void:
	var state := _duel(_spec(), _rook())
	state.combatants[1].position = Vector2(0, -7)
	var intent := _intent(state, 0)
	check(intent["move"].dot(Vector2(0, -1)) > 0.5, "a melee build closes the distance")
	var archer := _duel(_spec("bow_yew"), _rook())
	archer.combatants[1].position = Vector2(0, -6)
	check(_intent(archer, 0)["move"].dot(Vector2(0, -1)) <= 0.3, "an archer holds its distance")
	archer.combatants[1].position = Vector2(0, -0.2)
	check(_intent(archer, 0)["move"].dot(Vector2(0, -1)) < 0.0, "and backs off when closed on")


func test_build_changes_how_a_champion_fights() -> void:
	var sword := _profile("sword_training")
	var hammer := _profile("hammer_iron")
	var dagger := _profile("dagger_wolf")
	var bow := _profile("bow_yew")
	check(hammer["heavy_share"] > 0.35 and hammer["heavy_share"] > sword["heavy_share"] * 3.0,
			"a hammer favours heavy blows (%.2f vs %.2f)" % [hammer["heavy_share"], sword["heavy_share"]])
	check(dagger["dodges"] > sword["dodges"], "a dagger dodges rather than trades (%d vs %d)" % [dagger["dodges"], sword["dodges"]])
	check(dagger["open_share"] > sword["open_share"], "and strikes openings (%.2f vs %.2f)" % [dagger["open_share"], sword["open_share"]])
	check(bow["distance"] > sword["distance"] + 1.5, "a bow keeps its distance (%.1f vs %.1f m)" % [bow["distance"], sword["distance"]])


## How a build fights Rook over 30 seconds (or until someone falls).
func _profile(weapon_id: String) -> Dictionary:
	var players: Array[CombatantSpec] = [_spec(weapon_id)]
	var opponents: Array[CombatantSpec] = [_rook()]
	var sim := BattleSimulator.create(BattleState.create(Content.arena("meadow_ring"), players, opponents, 41))
	var distance := 0.0
	var samples := 0
	var heavy := 0
	var swings := 0
	var open_swings := 0
	var dodges := 0
	for i in 900:
		var target := sim.state.combatants[1]
		var target_open := DamagePhase.is_open(target) or target.is_exhausted()
		var frame := sim.step()
		if frame == null:
			break
		distance += sim.state.combatants[0].position.distance_to(target.position)
		samples += 1
		for event in frame.events:
			if event["actor"] != 0 or event["type"] != "action_start":
				continue
			match event["action"]:
				"attack", "heavy":
					swings += 1
					heavy += 1 if event["action"] == "heavy" else 0
					open_swings += 1 if target_open else 0
				"dodge":
					dodges += 1
	return {"heavy_share": float(heavy) / maxf(swings, 1), "open_share": float(open_swings) / maxf(swings, 1),
			"dodges": dodges, "distance": distance / maxf(samples, 1)}


func test_skill_turns_blows_aside() -> void:
	var novice := 0
	var expert := 0
	var drilled := {"skill:timing": GameEnums.Rank.EXPERT, "skill:dodge": GameEnums.Rank.EXPERT, "skill:block": GameEnums.Rank.EXPERT}
	for seed_value in 4:
		novice += _defended(_fight(_spec(), _rook(), 500 + seed_value))
		expert += _defended(_fight(_spec("sword_training", drilled, 60), _rook(), 500 + seed_value))
	check(expert > novice, "a drilled veteran evades, blocks and parries more (%d vs %d)" % [expert, novice])


static func _defended(sim: BattleSimulator) -> int:
	var count := 0
	for event in sim.battle_log.events:
		if event["type"] in ["evade", "block", "parry"] and event["actor"] == 0:
			count += 1
	return count
