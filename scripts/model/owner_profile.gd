class_name OwnerProfile
extends RefCounted
## The Keeper: lodge reputation (Owner Level), coins, mentors and belongings.
## Owner Level is separate from champion capability (mechanics §4).

signal changed
signal leveled_up(new_level: int)

var keeper_name: String = "Keeper"
var level: int = 1
var xp: int = 0
var coins: int = 0
var owned_trainers: Array[String] = []
var active_trainers: Array[String] = []
## Sessions taught per trainer (trainer progression / bond).
var trainer_sessions: Dictionary = {}
var owned_items: Array[String] = []
var flags: Dictionary = {}
var codex: Array[String] = []


static func create(now: float) -> OwnerProfile:
	var profile := OwnerProfile.new()
	profile.coins = Content.config.starting_coins
	profile.flags["journey_started_at"] = now
	return profile


static func xp_to_next(for_level: int) -> int:
	var config := Content.config
	return config.owner_xp_base + config.owner_xp_per_level * for_level


func add_xp(amount: int) -> int:
	var gained := 0
	xp += maxi(amount, 0)
	while level < Content.config.owner_max_level and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
		leveled_up.emit(level)
	changed.emit()
	return gained


## Active mentorship contracts the lodge can maintain at a level.
static func slots_for_level(for_level: int) -> int:
	var config := Content.config
	var slots := 0
	var levels: Array = config.trainer_slot_levels.keys()
	levels.sort()
	for threshold: int in levels:
		if for_level >= threshold:
			slots = int(config.trainer_slot_levels[threshold])
	return clampi(slots, 0, config.max_active_trainers)


func trainer_slots() -> int:
	return slots_for_level(level)


## Next owner level that opens another slot (0 when already at maximum).
func next_slot_level() -> int:
	var levels: Array = Content.config.trainer_slot_levels.keys()
	levels.sort()
	for threshold: int in levels:
		if threshold > level and slots_for_level(threshold) > trainer_slots():
			return threshold
	return 0


func lodge_title() -> String:
	var titles := Content.config.lodge_titles
	return titles[clampi(trainer_slots() - 1, 0, titles.size() - 1)]


func can_afford(amount: int) -> bool:
	return coins >= amount


func spend(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	changed.emit()
	return true


func earn(amount: int) -> void:
	coins += maxi(amount, 0)
	changed.emit()


func owns_item(item_id: String) -> bool:
	return owned_items.has(item_id)


func add_item(item_id: String) -> void:
	if not owned_items.has(item_id):
		owned_items.append(item_id)
		changed.emit()


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	changed.emit()


func is_flag_set(flag: String) -> bool:
	return flag.is_empty() or bool(flags.get(flag, false))


func unlock_codex(entry_id: String) -> bool:
	if codex.has(entry_id):
		return false
	codex.append(entry_id)
	return true


func to_dict() -> Dictionary:
	return {
		"keeper_name": keeper_name, "level": level, "xp": xp, "coins": coins,
		"owned_trainers": owned_trainers.duplicate(), "active_trainers": active_trainers.duplicate(),
		"trainer_slots": trainer_slots(),
		"trainer_sessions": trainer_sessions.duplicate(), "owned_items": owned_items.duplicate(),
		"flags": flags.duplicate(), "codex": codex.duplicate(),
	}


static func from_dict(data: Dictionary) -> OwnerProfile:
	var profile := OwnerProfile.new()
	profile.keeper_name = str(data.get("keeper_name", "Keeper"))
	profile.level = clampi(int(data.get("level", 1)), 1, Content.config.owner_max_level)
	profile.xp = int(data.get("xp", 0))
	profile.coins = int(data.get("coins", 0))
	for trainer_id in data.get("owned_trainers", []):
		if Content.trainer(str(trainer_id)) != null and not profile.owned_trainers.has(str(trainer_id)):
			profile.owned_trainers.append(str(trainer_id))
	for trainer_id in data.get("active_trainers", []):
		if profile.owned_trainers.has(str(trainer_id)) and profile.active_trainers.size() < profile.trainer_slots():
			profile.active_trainers.append(str(trainer_id))
	var sessions: Dictionary = data.get("trainer_sessions", {})
	for trainer_id: String in sessions:
		profile.trainer_sessions[trainer_id] = int(sessions[trainer_id])
	for item_id in data.get("owned_items", []):
		if Content.equipment(str(item_id)) != null:
			profile.owned_items.append(str(item_id))
	profile.flags = data.get("flags", {}).duplicate()
	for entry in data.get("codex", []):
		profile.codex.append(str(entry))
	return profile
