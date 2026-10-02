extends TestCase
## Story actions, the Chapter 1 quest line and the codex.


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")


func test_opening_beats_reference_valid_actions() -> void:
	for event_id: String in StoryEvents.EVENTS:
		for beat: Dictionary in StoryEvents.get_event(event_id):
			check(StoryEvents.SPEAKERS.has(beat.get("speaker", "narrator")), "%s: unknown speaker" % event_id)
			var action: String = beat.get("action", "")
			if action.begins_with("give_item:"):
				check(Content.equipment(action.get_slice(":", 1)) != null, action)
			if action.begins_with("recruit:"):
				check(Content.trainer(action.get_slice(":", 1)) != null, action)
	for trial: TrialData in Content.list("trials"):
		for event_id in [trial.story_after_win, trial.story_after_first]:
			check(event_id.is_empty() or StoryEvents.EVENTS.has(event_id), "missing event " + event_id)


func test_swordmaster_meeting_gives_sword_and_mentor() -> void:
	for beat: Dictionary in StoryEvents.get_event("meet_swordmaster"):
		StoryDirector.apply(beat.get("action", ""))
	check(Game.profile.owns_item("sword_training"))
	check(TrainerManager.is_active(Game.profile, "swordmaster_corin"))


func test_text_substitution() -> void:
	check_eq(StoryDirector.format("Hi {champion}"), "Hi Bruno")
	StoryDirector.rename_champion("  Maple  ")
	check_eq(Game.champion().name, "Maple")
	StoryDirector.rename_champion("   ")
	check_eq(Game.champion().name, "Maple", "blank names are ignored")


func test_quest_log_follows_flags() -> void:
	check_eq(QuestLog.current()["flag"], "inspected_champion")
	Game.set_flag("inspected_champion")
	check_eq(QuestLog.current()["flag"], "viewed_skill_matrix")
	for objective: Dictionary in QuestLog.CHAPTER_ONE:
		Game.set_flag(objective["flag"])
	check(QuestLog.current().is_empty())
	check_eq(QuestLog.progress().x, QuestLog.CHAPTER_ONE.size())


func test_quest_stations_exist() -> void:
	for objective: Dictionary in QuestLog.CHAPTER_ONE:
		check(WorldBuilder.STATIONS.has(objective["station"]), objective["station"])


func test_codex_unlocks_gradually() -> void:
	var before := CodexSystem.entries()
	check(not before.has("Aether Arts"))
	CodexSystem.unlock("aether")
	check(Game.is_flag_set("codex_unlocked"))
	check(CodexSystem.entries().has("Aether Arts"))


func test_dialogue_skip_applies_remaining_actions() -> void:
	var box := DialogueBox.new()
	root.add_child(box)
	box.play(StoryEvents.get_event("meet_swordmaster"))
	box._skip_all()
	check(Game.profile.owns_item("sword_training"), "skipping still hands over the sword")
	check(TrainerManager.is_active(Game.profile, "swordmaster_corin"))
	check(not box.visible)
	box.queue_free()
