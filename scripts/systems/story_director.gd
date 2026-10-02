class_name StoryDirector
extends RefCounted
## Applies story beat actions to the game state (story §16-22).


static func format(text: String) -> String:
	var champion := Game.champion()
	var keeper := Game.profile.keeper_name if Game.profile != null else "Keeper"
	return text.replace("{champion}", champion.name if champion != null else "your champion").replace("{keeper}", keeper)


## Runs a beat action ("kind:arg"). "name_champion" is resolved by the UI.
static func apply(action: String) -> void:
	if action.is_empty() or Game.profile == null:
		return
	var kind := action.get_slice(":", 0)
	var arg := action.get_slice(":", 1)
	match kind:
		"set_flag":
			Game.set_flag(arg)
		"give_item":
			if not Game.profile.owns_item(arg):
				Game.profile.add_item(arg)
				var item := Content.equipment(arg)
				Game.say("Received %s." % item.display_name, UiTheme.ACCENT)
		"recruit":
			if TrainerManager.recruit(Game.profile, arg, true).is_empty():
				Game.say("%s joined your mentorship circle." % Content.trainer(arg).display_name, UiTheme.GOOD)
		"unlock_codex":
			CodexSystem.unlock(arg)
		"coins":
			Game.profile.earn(int(arg))
	Game.save()


static func rename_champion(new_name: String) -> void:
	var champion := Game.champion()
	var clean := new_name.strip_edges().left(16)
	if champion != null and not clean.is_empty():
		champion.name = clean
		champion.changed.emit()
		Game.save()
