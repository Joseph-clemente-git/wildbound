extends TestCase
## UI/UX revision behaviours: notifications, badges, progressive disclosure.


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")


func test_notifications_stack_group_and_keep_history() -> void:
	Notify.clear()
	Notify.history.clear()
	Notify.push("Codex updated.")
	Notify.push("Codex updated.")
	Notify.push("Received Lodge Sword.")
	check_eq(Notify._stack.get_child_count(), 2, "duplicates are grouped")
	check(Notify._entries["Codex updated."]["count"] == 2)
	for i in 5:
		Notify.push("Message %d" % i)
	check(Notify._stack.get_child_count() <= Notify.MAX_VISIBLE, "never more than a few visible")
	check_eq(Notify.history.size(), 8, "everything is kept in the journal")
	Notify.clear()


func test_new_and_attention_badges() -> void:
	check(LodgeHud.is_new("champion"), "a revealed system starts NEW")
	check(not LodgeHud.is_new("training"), "unrevealed systems show nothing")
	Game.set_flag("seen_champion")
	check(not LodgeHud.is_new("champion"))
	check(not LodgeHud.needs_attention("training"), "no mentor yet")
	TrainerManager.recruit(Game.profile, "swordmaster_corin", true)
	check(LodgeHud.needs_attention("training"), "a session is possible")
	ConditionSystem.knock_out(Game.champion(), Game.now())
	check(LodgeHud.needs_attention("recovery"), "a knocked-out champion needs rest")
	check(not LodgeHud.needs_attention("journey"), "cannot fight while knocked out")


func test_guide_is_always_available() -> void:
	var entries := CodexSystem.entries()
	check(entries.has("Guide"))
	check(entries["Guide"].size() >= 5)


func test_opening_is_short() -> void:
	check(StoryEvents.get_event("opening").size() <= 8, "no text wall before play")
