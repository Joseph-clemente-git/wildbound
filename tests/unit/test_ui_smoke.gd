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
	for trainer_id in ["swordmaster_corin", "fire_mage_sera", "hammermaster_bram", "agility_wren"]:
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
	TrainerManager.recruit(Game.profile, "swordmaster_corin", true)
	var host := PanelHost.new()
	root.add_child(host)
	host.open("training", {"trainer": "swordmaster_corin", "target": "weapon:sword"})
	var panel: LodgePanel = host._current
	panel.call("_train")
	check_eq(Game.champion().skills.get_rank("weapon:sword"), GameEnums.Rank.NOVICE)
	check(Game.is_flag_set("trained_once"))
	host.free()


func test_scenes_instantiate_in_mid_game() -> void:
	for objective: Dictionary in QuestLog.CHAPTER_ONE.slice(0, 7):
		Game.set_flag(objective["flag"])
	Game.set_flag("world_map_unlocked")
	for route: String in ["journey", "battle_prep", "world_map", "lodge"]:
		Router.params = {"trial": "first_steps"}
		var scene: Node = load(Router.ROUTES[route]).instantiate()
		root.add_child(scene)
		check(scene.is_inside_tree(), route)
		scene.free()
	Router.params = {}
