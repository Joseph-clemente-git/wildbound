extends Node
## Balance check: the champion at three stages of development against every
## opponent, through the battle simulation (the same engine the game uses).
## Run: godot --headless --path . res://tools/balance_sim.tscn
## Win rates show whether each fight is beatable fresh, after some training
## and as a veteran. Outcomes come from the simulation, never a formula.

const RUNS := 24


func _ready() -> void:
	Game.autosave = false
	for setup: String in ["fresh", "trained", "veteran"]:
		print("== %s ==" % setup)
		for opponent: OpponentData in Content.list("opponents"):
			_simulate(setup, opponent)
	get_tree().quit()


func _champion(setup: String) -> Champion:
	Game.new_journey("Bruno")
	var champion := Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	match setup:
		"trained":
			for stat: String in ["attack", "evasion", "endurance", "health"]:
				champion.add_trained(stat, 5.0)
			champion.skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)
			champion.skills.set_rank("skill:block", GameEnums.Rank.FOUNDATION)
			champion.add_xp(300)
		"veteran":
			for stat: String in GameEnums.STATS:
				champion.add_trained(stat, 9.0)
			champion.skills.set_rank("weapon:sword", GameEnums.Rank.SKILLED)
			champion.skills.set_rank("skill:block", GameEnums.Rank.APPRENTICE)
			champion.skills.set_rank("skill:dodge", GameEnums.Rank.APPRENTICE)
			champion.skills.set_rank("magic:wind", GameEnums.Rank.FOUNDATION)
			champion.equipped_ability = "gale_push"
			champion.techniques.append("riposte")
			champion.armor_id = "armor_medium"
			champion.add_xp(900)
	return champion


func _simulate(setup: String, opponent: OpponentData) -> void:
	var wins := 0
	var decisions := 0
	var total_time := 0.0
	var hp_left := 0.0
	for run in RUNS:
		var champion := _champion(setup)
		var players: Array[CombatantSpec] = [CombatantSpec.from_champion(champion)]
		var opponents: Array[CombatantSpec] = [CombatantSpec.from_opponent(opponent)]
		var sim := BattleSimulator.create(BattleState.create(Content.arena("meadow_ring"), players, opponents, 1000 + run))
		sim.run()
		var outcome := sim.outcome()
		if outcome.player_won():
			wins += 1
			hp_left += outcome.side(0)["health_ratio"]
		if outcome.reason != "knockout":
			decisions += 1
		total_time += outcome.duration
	print("  vs %-10s win %3d%%  avg %5.1fs  hp left on win %3d%%  decided on time %d" % [opponent.id,
			roundi(100.0 * wins / RUNS), total_time / RUNS, roundi(100.0 * hp_left / maxf(wins, 1)), decisions])
