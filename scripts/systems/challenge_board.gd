class_name ChallengeBoard
extends RefCounted
## The Journey's fight board: which regions can be travelled and which fights
## each one offers. Selecting a fight only depends on the story and the
## fight itself; which champion enters, and whether it is ready, is decided
## after the fight is chosen.

enum Status { AVAILABLE, CLEARED, COMPLETED, LOCKED }

const STATUS_NAMES: Array[String] = ["Available", "Cleared", "Completed", "Locked"]


static func is_region_open(region: RegionData) -> bool:
	return TrainerManager.is_region_open(Game.profile, region.id)


## Regions the Journey lists, open ones first, each in map order.
static func regions() -> Array[RegionData]:
	var open: Array[RegionData] = []
	var closed: Array[RegionData] = []
	for region: RegionData in Content.list("regions"):
		if is_region_open(region):
			open.append(region)
		else:
			closed.append(region)
	return open + closed


## Every fight a region offers, locked ones included, in board order.
static func fights(region_id: String) -> Array[TrialData]:
	var result: Array[TrialData] = []
	for trial: TrialData in Content.list("trials"):
		if trial.region_id == region_id:
			result.append(trial)
	return result


static func status(trial: TrialData) -> Status:
	if not TrialSystem.is_unlocked(trial):
		return Status.LOCKED
	if Game.is_flag_set(trial.cleared_flag()):
		return Status.CLEARED if trial.repeatable else Status.COMPLETED
	return Status.AVAILABLE


static func can_select(trial: TrialData) -> bool:
	var current := status(trial)
	return current == Status.AVAILABLE or current == Status.CLEARED


## Fights in a region the Keeper has not won yet and can take on now.
static func open_count(region_id: String) -> int:
	return fights(region_id).filter(func(trial: TrialData) -> bool:
		return status(trial) == Status.AVAILABLE).size()


## What still stands between the Keeper and a locked fight, in plain words.
static func requirements(trial: TrialData) -> PackedStringArray:
	var missing := PackedStringArray()
	var region := Content.region(trial.region_id)
	if region != null and not is_region_open(region):
		missing.append("reach %s (Chapter %d)" % [region.display_name, region.chapter])
	for flag in trial.requires_flags:
		if not Game.is_flag_set(flag):
			missing.append(requirement_text(flag))
	return missing


static func requirement_text(flag: String) -> String:
	match flag:
		"equipped_weapon":
			return "equip a weapon"
		"trained_once":
			return "train once"
		"first_trial_done":
			return "finish the First Steps Trial"
	if flag.begins_with("cleared_"):
		var trial := Content.trial(flag.trim_prefix("cleared_"))
		if trial != null:
			return "win the " + trial.display_name
	return flag.replace("_", " ")
