extends TestCase
## Stage 7 of the battle simulation: the fixed-tick pipeline. Battles advance
## in discrete ticks through the same ordered phases; the outcome comes from
## what the phases do, never from the simulator itself.


## Records the order phases run in.
class RecordingPhase extends SimulationPhase:
	var trace: Array

	func _init(phase_name: String, shared: Array) -> void:
		super(phase_name)
		trace = shared

	func run(_state: BattleState, frame: SimFrame) -> void:
		trace.append("%d:%s" % [frame.tick, name])


## A stand-in damage phase: team 0 lands a seeded hit on team 1 each tick.
class TestDamagePhase extends SimulationPhase:
	func _init() -> void:
		super("damage")

	func run(state: BattleState, frame: SimFrame) -> void:
		for fighter in state.living(1):
			var amount := state.rng.randf_range(20.0, 40.0)
			fighter.health -= amount
			frame.emit("damage", 0, fighter.index, {"amount": amount})


var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"


func _sim(seed_value: int = 99) -> BattleSimulator:
	return BattleSimulator.create(BattleState.for_fight(Content.trial("stonewall_bout"), champion, seed_value))


func test_pipeline_follows_the_design_order() -> void:
	var sim := _sim()
	var names: Array[String] = []
	for phase in sim.phases:
		names.append(phase.name)
	check_eq(names, BattleSimulator.PIPELINE)
	check_eq(BattleSimulator.PIPELINE, ["decision", "action", "contact", "damage", "force", "movement",
			"stamina", "recovery", "knockout"])
	check(sim.phases[7] is CooldownPhase)
	check(sim.phases[8] is KnockoutPhase)


func test_every_phase_runs_each_tick_in_order() -> void:
	var sim := _sim()
	var trace: Array = []
	for phase_name: String in BattleSimulator.PIPELINE:
		if phase_name != "knockout":
			sim.use_phase(RecordingPhase.new(phase_name, trace))
	sim.step()
	sim.step()
	var expected: Array = []
	for tick in [1, 2]:
		for phase_name: String in BattleSimulator.PIPELINE.slice(0, 8):
			expected.append("%d:%s" % [tick, phase_name])
	check_eq(trace, expected)


func test_ticks_are_discrete_and_fixed() -> void:
	var sim := _sim()
	check_eq(sim.tick_rate, Content.config.simulation_tick_rate)
	for i in 45:
		sim.step()
	check_eq(sim.state.tick, 45)
	check_near(sim.state.time, 45.0 / sim.tick_rate, 0.00001)


func test_without_combat_nothing_is_decided() -> void:
	var sim := _sim()
	var start := sim.state.snapshot()
	var battle_log := sim.run()
	check(sim.state.finished)
	check_eq(sim.state.winner_team, -1, "the simulator never picks a winner by itself")
	check_eq(sim.state.tick, sim.max_ticks)
	check_eq(battle_log.duration(), Content.config.simulation_max_seconds, "exact clock after thousands of ticks")
	var end := battle_log.events_of("battle_end")
	check_eq(end.size(), 1)
	check_eq(end[0]["reason"], "time")
	for i in sim.state.combatants.size():
		check_eq(sim.state.combatants[i].health, start["combatants"][i]["health"], "no phase, no damage")


func test_knockout_ends_the_battle() -> void:
	var sim := _sim()
	sim.use_phase(TestDamagePhase.new())
	var battle_log := sim.run()
	check(sim.state.finished)
	check_eq(sim.state.winner_team, BattleState.PLAYER_TEAM)
	var rook := sim.state.team(BattleState.OPPONENT_TEAM)[0]
	check_eq(rook.action, CombatantState.Action.KO)
	check_eq(rook.health, 0.0)
	check_eq(battle_log.events_of("knockout").size(), 1)
	check_eq(battle_log.events_of("knockout")[0]["actor"], rook.index)
	check_eq(battle_log.events_of("battle_end")[0]["reason"], "knockout")
	check(sim.state.tick < 200, "ended as soon as the knockout happened")
	check(sim.step() == null, "a finished battle does not advance")


func test_same_seed_same_battle() -> void:
	var a := _sim(5)
	a.use_phase(TestDamagePhase.new())
	var b := _sim(5)
	b.use_phase(TestDamagePhase.new())
	check_eq(JSON.stringify(a.run().to_dict()), JSON.stringify(b.run().to_dict()), "deterministic")
	var c := _sim(6)
	c.use_phase(TestDamagePhase.new())
	check(JSON.stringify(c.run().events) != JSON.stringify(a.battle_log.events), "the seed is the only variation")


func test_cooldowns_exhaustion_and_effects_count_down() -> void:
	var sim := _sim()
	var hero := sim.state.combatants[0]
	hero.cooldowns["magic"] = 0.1
	hero.exhausted_time = 0.05
	hero.effects.append({"kind": "burn", "dps": 4.0, "time": 0.2, "source": 1})
	for i in 8:
		sim.step()
	check(not hero.cooldowns.has("magic"))
	check_eq(hero.exhausted_time, 0.0)
	check(hero.effects.is_empty())
	var battle_log := sim.battle_log
	check_eq(battle_log.events_of("cooldown_ready").size(), 1)
	check_eq(battle_log.events_of("recovered_breath").size(), 1)
	check_eq(battle_log.events_of("effect_ended")[0]["kind"], "burn")


func test_log_keeps_keyframes_for_replay() -> void:
	var sim := _sim()
	for i in 30:
		sim.step()
	var battle_log := sim.battle_log
	check_eq(battle_log.keyframes[0]["tick"], 0, "starts with the initial state")
	check_eq(battle_log.keyframes.size(), 1 + 30 / sim.keyframe_ticks)
	check_eq(battle_log.keyframes[-1]["tick"], 30)
	check_eq(battle_log.header["combatants"].size(), 2)
	check_eq(battle_log.header["seed"], 99)
	sim.run()
	check_eq(battle_log.keyframes[-1]["tick"], sim.state.tick, "ends with the final state")
	check_eq(battle_log.final["finished"], true)


func test_headless_run_is_fast() -> void:
	var started := Time.get_ticks_msec()
	_sim().run()
	var elapsed := Time.get_ticks_msec() - started
	check(elapsed < 3000, "a full-length battle simulates in %d ms" % elapsed)
