extends TestCase
## End-to-end Chapter 1: the full loop from New Journey to the road beyond,
## driven through the same panels, systems and battle simulation the game uses.
## Every battle is simulated from the champion's build; time passes between
## them so energy and knockouts recover, and the champion trains with its
## mentors.

var host: PanelHost
var log_lines: PackedStringArray = []


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 2000000.0


func _apply_event(event_id: String) -> void:
	for beat: Dictionary in StoryEvents.get_event(event_id):
		StoryDirector.apply(beat.get("action", ""))


func _panel(panel_id: String, options: Dictionary = {}) -> LodgePanel:
	host.open(panel_id, options)
	return host._current


func _pass_time(hours: float) -> void:
	Game.time_override += hours * 3600.0
	Game.tick_condition()


func _fight(trial_id: String, seed_value: int) -> bool:
	var champion := Game.champion()
	var trial := Content.trial(trial_id)
	if not TrialSystem.entry_blocker(champion, trial).is_empty():
		_pass_time(6.0)
	check_eq(TrialSystem.enter(champion, trial), "", "can enter " + trial_id)
	var result := BattleSession.start(trial, champion, seed_value).result
	log_lines.append("%s: %s in %ds, +%d coins, growth %d" % [trial_id, "won" if result["won"] else "lost",
			roundi(result["duration"]), result["coins"], result["growths"].size()])
	if not str(result["story"]).is_empty():
		_apply_event(result["story"])
	return result["won"]


func _train_session(trainer_id: String, target: String) -> void:
	var champion := Game.champion()
	if champion.energy < 45.0:
		_pass_time(3.0)
	var panel := _panel("training", {"trainer": trainer_id, "target": target})
	panel.call("_train")
	host.close()


func test_chapter_one_can_be_completed() -> void:
	host = PanelHost.new()
	root.add_child(host)
	# Title -> New Journey -> opening story.
	Game.new_journey()
	_apply_event("opening")
	StoryDirector.rename_champion("Bruno")
	check(Game.is_flag_set("opening_done"))
	check(Game.profile.owns_item("token_mentor"))
	# Inspect the champion and study the Skill Matrix.
	Game.set_flag("inspected_champion")
	_panel("champion", {"tab": "skills"})
	host.close()
	check(Game.is_flag_set("viewed_skill_matrix"))
	# Meet the Swordmaster at the Trainer Board.
	_apply_event("meet_swordmaster")
	Game.set_flag("met_first_trainer")
	check(TrainerManager.is_active(Game.profile, "swordmaster_corin"))
	# First training session and equipping the sword.
	_train_session("swordmaster_corin", "weapon:sword")
	check(Game.is_flag_set("trained_once"))
	var equipment := _panel("equipment")
	equipment.call("_equip", "sword_training")
	host.close()
	check(Game.is_flag_set("equipped_weapon"))
	# The First Steps Trial (the tutorial).
	check(TrialSystem.is_unlocked(Content.trial("first_steps")))
	_fight("first_steps", 101)
	check(Game.is_flag_set("first_trial_done"))
	check(Game.is_flag_set("world_map_unlocked"), "Marten hands over the map")
	# Rest at the Rest Area.
	var rest := _panel("recovery")
	_pass_time(1.0)
	rest.call("_rest")
	host.close()
	check(Game.is_flag_set("rested_once"))
	# Develop and fight until the regional trial is won.
	var attempts := 0
	var targets := ["weapon:sword", "skill:block", "skill:attack", "skill:timing", "skill:attack_control"]
	while not Game.is_flag_set("chapter_one_complete") and attempts < 45:
		attempts += 1
		for target: String in targets:
			if TrainingSystem.preview(Content.trainer("swordmaster_corin"), Game.champion(), target, Game.profile)["ok"]:
				_train_session("swordmaster_corin", target)
				break
		_maybe_hire_and_learn()
		var trial_id := "valley_regional"
		if not Game.is_flag_set("cleared_stonewall_bout"):
			trial_id = "stonewall_bout"
		elif not Game.is_flag_set("cleared_meadow_sprint"):
			trial_id = "meadow_sprint"
		_fight(trial_id, 300 + attempts)
		_pass_time(2.0)
	print("\n    ".join(log_lines))
	print("    Keeper level %d, mentors %d/%d, Bruno level %d (%s), coins %d" % [Game.profile.level,
			Game.profile.active_trainers.size(), Game.profile.trainer_slots(), Game.champion().level,
			Game.champion().capability_name(), Game.profile.coins])
	check(Game.is_flag_set("cleared_valley_regional"), "won the regional trial within %d battles" % attempts)
	check(Game.is_flag_set("chapter_one_complete"))
	check(QuestLog.current().is_empty(), "every Chapter 1 objective done")
	check(Game.profile.level >= 3, "the lodge's reputation grew")
	check(Game.champion().experience.active_tracks().size() >= 4, "Bruno lived many kinds of experience")
	# The save survives the whole chapter.
	var snapshot := JSON.stringify(Game.to_dict())
	Game.load_from_dict(JSON.parse_string(snapshot))
	check_eq(JSON.stringify(Game.to_dict()), snapshot)
	host.free()


## A Keeper with coins recruits Wren (agility) once a second slot opens and
## learns Riposte when ready.
func _maybe_hire_and_learn() -> void:
	var profile := Game.profile
	if profile.trainer_slots() >= 2 and not profile.owned_trainers.has("agility_wren") and profile.coins > 400:
		TrainerManager.recruit(profile, "agility_wren")
	if profile.owned_trainers.has("agility_wren") and TrainerManager.is_active(profile, "agility_wren"):
		var wren := Content.trainer("agility_wren")
		for target: String in ["stat:evasion", "skill:dodge"]:
			if TrainingSystem.preview(wren, Game.champion(), target, profile)["ok"]:
				_train_session("agility_wren", target)
				break
	var riposte := Content.technique("riposte")
	if TechniqueSystem.learn_blocker(Game.champion(), riposte, profile).is_empty():
		TechniqueSystem.learn(Game.champion(), riposte, profile)
		log_lines.append("learned Riposte")
