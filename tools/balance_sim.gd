extends Node
## Balance simulation: AI-piloted champion vs every Chapter 1 opponent.
## Run: godot --headless --path . res://tools/balance_sim.tscn
## The pilot uses a "competent player" profile; win rates show whether the
## chapter is beatable fresh vs after some training.

const RUNS := 24
const DT := 1.0 / 30.0

var pilot_profile: OpponentData


func _ready() -> void:
	Game.autosave = false
	pilot_profile = OpponentData.new()
	pilot_profile.id = "pilot"
	pilot_profile.aggression = 0.55
	pilot_profile.block_skill = 0.3
	pilot_profile.dodge_skill = 0.4
	pilot_profile.heavy_chance = 0.2
	pilot_profile.magic_chance = 0.2
	pilot_profile.reaction_time = 0.3
	pilot_profile.preferred_range = 1.8
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
	var total_time := 0.0
	var hp_left := 0.0
	for run in RUNS:
		var champion := _champion(setup)
		var battle := BattleManager.new()
		battle.auto_step = false
		add_child(battle)
		var hero := Combatant.new()
		hero.setup_from_champion(champion)
		var foe := Combatant.new()
		foe.setup_from_opponent(opponent)
		battle.add_child(hero)
		battle.add_child(foe)
		battle.setup(Content.arena("meadow_ring"), hero, foe)
		battle.ai = AiController.new(foe, opponent, 1000 + run)
		battle.player_controller = AiController.new(hero, pilot_profile, 2000 + run)
		battle.start()
		while not battle.finished:
			battle.step(DT)
		if battle.winner == hero:
			wins += 1
			hp_left += hero.health_ratio()
		total_time += battle.time
		battle.free()
	print("  vs %-10s win %3d%%  avg %5.1fs  hp left on win %3d%%  power ratio %.2f" % [opponent.id,
			roundi(100.0 * wins / RUNS), total_time / RUNS, roundi(100.0 * hp_left / maxf(wins, 1)),
			PowerRating.for_opponent(opponent) / Game.champion().power_rating()])
