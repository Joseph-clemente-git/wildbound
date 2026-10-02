extends Node
## Persistent, versioned save data (autoload "Saves").
##
## The save is JSON wrapped in an envelope with a format version. Older saves
## pass through MIGRATIONS in order before loading. Writes go to a temporary
## file first and the previous save is kept as a backup.

signal saved
signal load_failed(reason: String)

const SAVE_PATH := "user://wildbound_save.json"
const BACKUP_PATH := "user://wildbound_save.bak.json"
const VERSION := 2

## from_version -> Callable(Dictionary) -> Dictionary returning version + 1 data.
var MIGRATIONS := {
	0: _migrate_0_to_1,
	1: _migrate_1_to_2,
}

var path_override := ""  # tests write elsewhere


func save_path() -> String:
	return path_override if not path_override.is_empty() else SAVE_PATH


func backup_path() -> String:
	return save_path().get_basename() + ".bak.json"


func has_save() -> bool:
	return FileAccess.file_exists(save_path())


func save_game(game: Dictionary) -> bool:
	var envelope := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game": game,
	}
	var tmp_path := save_path() + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Saves: cannot write %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(envelope, "\t"))
	file.close()
	var dir := DirAccess.open(save_path().get_base_dir())
	if has_save():
		dir.copy(save_path(), backup_path())
	var error := dir.rename(tmp_path, save_path())
	if error != OK:
		push_error("Saves: rename failed (%s)" % error_string(error))
		return false
	saved.emit()
	return true


## Returns the migrated game dictionary, or {} if nothing valid was found.
func load_game() -> Dictionary:
	for path: String in [save_path(), backup_path()]:
		if not FileAccess.file_exists(path):
			continue
		var data := _read(path)
		if not data.is_empty():
			return data
	return {}


func delete_save() -> void:
	for path: String in [save_path(), backup_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		load_failed.emit("corrupt save at " + path)
		return {}
	return migrate(parsed)


## Brings an envelope up to the current version and returns its game data.
func migrate(envelope: Dictionary) -> Dictionary:
	var version := int(envelope.get("version", 0))
	if version > VERSION:
		load_failed.emit("save is from a newer version (%d)" % version)
		return {}
	var game: Dictionary = envelope.get("game", envelope if version == 0 else {})
	while version < VERSION:
		game = MIGRATIONS[version].call(game)
		version += 1
	return game


## Version 0 (pre-envelope prototype saves) stored the profile at the root.
func _migrate_0_to_1(game: Dictionary) -> Dictionary:
	var result := game.duplicate(true)
	if not result.has("profile"):
		result = {"profile": game, "champions": game.get("champions", [])}
	return result


## Version 2 (battle simulation): champions gain their animal's Natural
## Foundation skills, and battle records the summary fields the Journey and
## replays read. Older records carry no replay and are simply not watchable.
func _migrate_1_to_2(game: Dictionary) -> Dictionary:
	var result := game.duplicate(true)
	for champion: Variant in result.get("champions", []):
		if not champion is Dictionary:
			continue
		var animal := Content.animal(str(champion.get("animal_id", "humanoid_dog")))
		var skills: Dictionary = champion.get("skills", {})
		var ranks: Dictionary = skills.get("ranks", {})
		skills["ranks"] = ranks
		champion["skills"] = skills
		if animal != null:
			for target: String in animal.starting_skills:
				if not ranks.has(target):
					ranks[target] = int(animal.starting_skills[target])
		for entry: Variant in champion.get("history", []):
			if entry is Dictionary:
				entry["reason"] = entry.get("reason", "")
				entry["replay"] = entry.get("replay", {})
	return result

