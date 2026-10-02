extends Node
## Screenshot scenarios for visual review. Run with Movie Maker, e.g.:
##   godot --path . --write-movie out.png --fixed-fps 10 --quit-after 60 \
##       res://tests/visual/scenario.tscn -- --scenario=lodge
## Each scenario prepares game state, routes to a scene and can schedule
## actions ([seconds, Callable]).

var _actions: Array = []
var _time := 0.0


func _ready() -> void:
	var scenario := "lodge"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.trim_prefix("--scenario=")
	# Detach from current_scene so routing to another scene does not free us.
	get_tree().current_scene = null
	Saves.path_override = "user://scenario_save.json"
	Game.new_journey("Bruno")
	Game.set_flag("opening_done")
	call("_scenario_" + scenario)


func _process(delta: float) -> void:
	_time += delta
	while not _actions.is_empty() and _time >= _actions[0][0]:
		var action: Array = _actions.pop_front()
		(action[1] as Callable).call()


func _at(seconds: float, action: Callable) -> void:
	_actions.append([seconds, action])


func _lodge() -> Node:
	return get_tree().current_scene


func _progress(flags: Array) -> void:
	for flag: String in flags:
		Game.set_flag(flag)


func _scenario_story() -> void:
	Router.go("story", {"event": "opening"})


func _scenario_lodge() -> void:
	Router.go("lodge")


func _scenario_lodge_context() -> void:
	Router.go("lodge")
	_at(1.5, func() -> void: _lodge().select_station("champion"))


func _scenario_lodge_mid() -> void:
	_prepare_mid()
	Router.go("lodge")


func _prepare_mid() -> void:
	_progress(["inspected_champion", "viewed_skill_matrix", "met_first_trainer", "trained_once",
			"equipped_weapon", "first_trial_done", "world_map_unlocked", "codex_unlocked"])
	TrainerManager.recruit(Game.profile, "swordmaster_corin", true)
	Game.profile.add_item("sword_training")
	Game.champion().weapon_id = "sword_training"


func _scenario_panel() -> void:
	_scenario_lodge_mid()
	var panel := "champion"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--panel="):
			panel = arg.trim_prefix("--panel=")
	_at(1.0, func() -> void: _lodge().open_panel(panel))


func _scenario_arena() -> void:
	_prepare_mid()
	var trial := "first_steps"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--trial="):
			trial = arg.trim_prefix("--trial=")
	Router.go("arena", {"trial": trial})
	# Let an AI pilot the player so the battle plays itself for review.
	_at(3.2, func() -> void:
		var arena := get_tree().current_scene
		var pilot := AiController.new(arena.hero, Content.opponent("juniper"), 5)
		arena.battle.player_controller = pilot)


func _scenario_result() -> void:
	_prepare_mid()
	TrainerManager.recruit(Game.profile, "agility_wren", true)
	var champion := Game.champion()
	champion.experience.add("evasion", 70.0)
	var outcome := {"trial_id": "stonewall_bout", "opponent_id": "rook", "won": true, "forfeited": false,
			"duration": 74.0, "difficulty_ratio": 1.2, "difficulty_multiplier": 1.25,
			"tallies": {"hits": 9, "heavy_hits": 2, "staggers": 3, "dodges": 7, "perfect_dodges": 2,
					"blocks": 4, "perfect_blocks": 1, "exhaustions": 1},
			"experience": {"evasion": 24.0, "weapon:sword": 18.0, "offensive": 11.0, "endurance": 6.0, "resilience": 3.0},
			"growths": [{"text": "Evasion +2.0"}, {"text": "Dodge reached Apprentice"}]}
	Router.go("result", {"outcome": TrialSystem.apply_result(outcome)})


func _scenario_prep() -> void:
	_prepare_mid()
	Router.go("battle_prep", {"trial": "valley_regional"})


func _scenario_map() -> void:
	_prepare_mid()
	Router.go("world_map")


func _scenario_story_porch() -> void:
	Router.go("story", {"event": "opening"})
	_at(1.0, func() -> void:
		var box: DialogueBox = get_tree().current_scene._dialogue
		for i in 4:
			box._finish_reveal()
			box._advance())
