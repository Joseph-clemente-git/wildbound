extends Node
## Persistent, versioned save data (autoload "Saves"). Filled in by later milestones.

const SAVE_PATH := "user://wildbound_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
