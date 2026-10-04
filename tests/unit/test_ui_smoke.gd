extends TestCase
## Every lodge panel builds and rebuilds without errors, early and late game.


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")


func _open_all() -> void:
	var host := PanelHost.new()
	root.add_child(host)
	for panel_id: String in PanelHost.PANELS:
		host.open(panel_id)
		check(host.has_open_panel(), "panel opened: " + panel_id)
		var panel: LodgePanel = host._current
		panel.rebuild()
		check(panel.body.get_child_count() > 0, "panel has content: " + panel_id)
		host.close()
	host.free()


func test_panels_early_game() -> void:
	_open_all()


func test_panels_late_game() -> void:
	var profile := Game.profile
	for objective: Dictionary in QuestLog.CHAPTER_ONE:
		Game.set_flag(objective["flag"])
	profile.level = 12
	profile.coins = 9999
	for trainer_id in ["swordmaster_yenbi", "fire_mage_sera", "hammermaster_bram", "agility_wren"]:
		TrainerManager.recruit(profile, trainer_id, true)
	CodexSystem.unlock("aether")
	var champion := Game.champion()
	for item_id in ["sword_training", "hammer_iron", "armor_heavy"]:
		profile.add_item(item_id)
	champion.weapon_id = "hammer_iron"
	champion.skills.set_rank("magic:fire", GameEnums.Rank.APPRENTICE)
	champion.equipped_ability = "ember_bolt"
	champion.experience.add("evasion", 40.0)
	champion.experience.add("weapon:hammer", 20.0)
	champion.record_battle({"trial": "First Steps Trial", "opponent": "pip", "won": true})
	ConditionSystem.knock_out(champion, Game.now())
	_open_all()


func test_training_panel_flow() -> void:
	TrainerManager.recruit(Game.profile, "swordmaster_yenbi", true)
	var host := PanelHost.new()
	root.add_child(host)
	host.open("training", {"trainer": "swordmaster_yenbi", "target": "weapon:sword"})
	var panel: LodgePanel = host._current
	panel.call("_train")
	check_eq(Game.champion().skills.get_rank("weapon:sword"), GameEnums.Rank.NOVICE)
	check(Game.is_flag_set("trained_once"))
	host.free()



func test_lodge_shows_a_mentor_as_soon_as_she_joins() -> void:
	var lodge: Node = load(Router.ROUTES["lodge"]).instantiate()
	root.add_child(lodge)
	check(lodge.mentor_visual("swordmaster_yenbi") == null)
	TrainerManager.recruit(Game.profile, "swordmaster_yenbi", true)
	check(lodge.mentor_visual("swordmaster_yenbi") != null, "Yenbi stands in the lodge right after joining")
	TrainerManager.deactivate(Game.profile, "swordmaster_yenbi")
	check(lodge.mentor_visual("swordmaster_yenbi") == null, "and leaves when no longer active")
	lodge.free()


func test_training_plays_out_in_the_yard() -> void:
	TrainerManager.recruit(Game.profile, "swordmaster_yenbi", true)
	var lodge: Node = load(Router.ROUTES["lodge"]).instantiate()
	root.add_child(lodge)
	lodge.open_panel("training", {"trainer": "swordmaster_yenbi", "target": "weapon:sword"})
	var panel: LodgePanel = lodge.panels._current
	panel.call("_train")
	check_eq(Game.champion().skills.get_rank("weapon:sword"), GameEnums.Rank.NOVICE, "the lesson is applied (and saved) up front")
	check(lodge.is_training(), "then the session plays in the Training Yard")
	var session: TrainingSession = lodge._training
	check_eq(session.seconds, Content.config.training_base_seconds, "as long as the plan said (a first lesson)")
	session._process(TrainingSession.GATHER_SECONDS + 0.01)
	check(session.champion.position.distance_to(WorldBuilder.STATIONS["training"]) < 1.5, "the champion is at the yard")
	session._process(session.seconds + 0.01)
	session._process(TrainingSession.CLOSING_SECONDS + 0.01)
	session._process(TrainingSession.RETURN_SECONDS + 0.01)
	check(not lodge.is_training())
	check(lodge.panels.has_open_panel(), "the Training Yard reopens with the result")
	check(not str(lodge.panels._current.get("_last_result")).is_empty())
	lodge.free()


func test_every_lesson_has_a_drill_the_people_can_perform() -> void:
	var person := ProceduralHumanVisual.new()
	for trainer: TrainerData in Content.list("trainers"):
		for target in Array(trainer.primary_discipline) + Array(trainer.secondary_discipline):
			for pair: Array in TrainingSession.drill_for(target):
				check(person.has_clip(pair[0]) and person.has_clip(pair[1]), "%s drill clips" % target)
	person.free()
	var config := Content.config
	check_eq(TrainingSystem.session_seconds(Game.champion(), "weapon:sword"), config.training_base_seconds,
			"a first lesson takes the base time")
	Game.champion().skills.set_rank("weapon:sword", GameEnums.Rank.MASTER)
	check(TrainingSystem.session_seconds(Game.champion(), "weapon:sword") <= config.training_max_seconds)

func test_scenes_instantiate_in_mid_game() -> void:
	for objective: Dictionary in QuestLog.CHAPTER_ONE.slice(0, 7):
		Game.set_flag(objective["flag"])
	Game.set_flag("world_map_unlocked")
	for route: String in ["journey", "fight_preview", "champion_select", "battle_prep", "world_map", "lodge"]:
		Router.params = {"trial": "first_steps"}
		var scene: Node = load(Router.ROUTES[route]).instantiate()
		root.add_child(scene)
		check(scene.is_inside_tree(), route)
		scene.free()
	Router.params = {}
