extends Node
## Live game session (autoload "Game").
##
## Owns the Keeper's profile and champions, exposes story flags, and persists
## everything through Saves. Systems mutate the models; screens listen to
## `changed` to refresh.

signal changed
signal flag_set(flag: String)
## Short narrative messages for the UI ("Bruno feels rested.").
signal notice(text: String, color: Color)

const STARTING_ITEMS: Array[String] = ["armor_light"]
const CONDITION_TICK_SECONDS := 5.0

var profile: OwnerProfile
var champions: Array[Champion] = []
var selected_uid: String = ""
## Tests can freeze time; negative means use the system clock.
var time_override: float = -1.0
var autosave := true

var _tick := 0.0


func _process(delta: float) -> void:
	if profile == null:
		return
	_tick += delta
	if _tick >= CONDITION_TICK_SECONDS:
		_tick = 0.0
		tick_condition()


func now() -> float:
	return time_override if time_override >= 0.0 else Time.get_unix_time_from_system()


func is_active() -> bool:
	return profile != null and not champions.is_empty()


# --- Journey lifecycle ------------------------------------------------------------

func new_journey(champion_name: String = "") -> void:
	var animal := Content.animal("humanoid_dog")
	profile = OwnerProfile.create(now())
	for item_id in STARTING_ITEMS:
		profile.add_item(item_id)
	if champion_name.strip_edges().is_empty():
		champion_name = animal.default_names[0] if not animal.default_names.is_empty() else "Bruno"
	var champion := Champion.create(animal, champion_name.strip_edges(), now())
	champion.armor_id = "armor_light"
	champions = [champion]
	selected_uid = champion.uid
	_connect_models()
	save()
	changed.emit()


func continue_journey() -> bool:
	var data := Saves.load_game()
	if data.is_empty():
		return false
	return load_from_dict(data)


func load_from_dict(data: Dictionary) -> bool:
	var profile_data: Variant = data.get("profile")
	if not profile_data is Dictionary:
		return false
	profile = OwnerProfile.from_dict(profile_data)
	champions.clear()
	for entry in data.get("champions", []):
		if entry is Dictionary:
			champions.append(Champion.from_dict(entry))
	if champions.is_empty():
		profile = null
		return false
	selected_uid = str(data.get("selected_uid", champions[0].uid))
	if champion() == null:
		selected_uid = champions[0].uid
	_connect_models()
	tick_condition()
	changed.emit()
	return true


func to_dict() -> Dictionary:
	var champion_data: Array = []
	for entry in champions:
		champion_data.append(entry.to_dict())
	return {"profile": profile.to_dict(), "champions": champion_data, "selected_uid": selected_uid}


func save() -> bool:
	if not autosave or profile == null:
		return false
	return Saves.save_game(to_dict())


func close_journey() -> void:
	profile = null
	champions.clear()
	selected_uid = ""


# --- Accessors --------------------------------------------------------------------

## The currently selected champion (the MVP owns one, the API supports many).
func champion() -> Champion:
	for entry in champions:
		if entry.uid == selected_uid:
			return entry
	return null


func select_champion(uid: String) -> void:
	selected_uid = uid
	changed.emit()


func is_flag_set(flag: String) -> bool:
	return profile != null and profile.is_flag_set(flag)


## Sets a story flag once; returns true the first time.
func set_flag(flag: String) -> bool:
	if profile == null or profile.is_flag_set(flag):
		return false
	profile.set_flag(flag)
	flag_set.emit(flag)
	save()
	return true


func say(text: String, color: Color = UiTheme.TEXT) -> void:
	notice.emit(text, color)


## Applies passive energy recovery and knockout timers to every champion.
func tick_condition() -> void:
	var any := false
	for entry in champions:
		var events := ConditionSystem.apply_passive(entry, now())
		if events.has("recovered_ko"):
			say("%s has recovered from the knockout." % entry.name, UiTheme.GOOD)
		any = any or not events.is_empty()
	if any:
		save()
		changed.emit()


func _connect_models() -> void:
	if not profile.changed.is_connected(_on_model_changed):
		profile.changed.connect(_on_model_changed)
	if not profile.leveled_up.is_connected(_on_owner_level):
		profile.leveled_up.connect(_on_owner_level)
	for entry in champions:
		if not entry.changed.is_connected(_on_model_changed):
			entry.changed.connect(_on_model_changed)


func _on_model_changed() -> void:
	changed.emit()


func _on_owner_level(new_level: int) -> void:
	say("Your lodge's reputation grows! Keeper level %d." % new_level, UiTheme.ACCENT)
	if OwnerProfile.slots_for_level(new_level) > OwnerProfile.slots_for_level(new_level - 1):
		say("The %s can now keep %d active mentors." % [profile.lodge_title(), profile.trainer_slots()], UiTheme.GOOD)
