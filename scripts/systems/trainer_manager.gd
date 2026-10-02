class_name TrainerManager
extends RefCounted
## The lodge's mentorship circle (mechanics §32-37, prompts 10-12).
##
## Trainers are universal and shared by every owned champion. The number of
## active mentorship contracts depends on Owner Level (max 5). Rarity changes
## training capability only — never battle stats.


static func rarity_efficiency(trainer: TrainerData) -> float:
	return Content.config.rarity_efficiency[trainer.rarity] * trainer.personal_efficiency


## Highest skill rank this trainer can teach.
static func rank_cap(trainer: TrainerData) -> int:
	return Content.config.rarity_rank_cap[trainer.rarity]


## Highest stat value this trainer can develop.
static func stat_cap(trainer: TrainerData) -> float:
	return Content.config.rarity_stat_cap[trainer.rarity]


static func technique_tier(trainer: TrainerData) -> int:
	return Content.config.rarity_technique_tier[trainer.rarity]


static func teaches_secondary(trainer: TrainerData) -> bool:
	return Content.config.rarity_secondary[trainer.rarity]


## Traits the trainer can actually express at their rarity.
static func active_traits(trainer: TrainerData) -> PackedStringArray:
	var slots: int = Content.config.rarity_trait_slots[trainer.rarity]
	return trainer.traits.slice(0, slots)


## Targets this trainer can currently develop (skill coverage).
static func coverage(trainer: TrainerData) -> PackedStringArray:
	var result := trainer.primary_discipline.duplicate()
	if teaches_secondary(trainer):
		result.append_array(trainer.secondary_discipline)
	return result


static func teachable_techniques(trainer: TrainerData) -> Array[TechniqueData]:
	var result: Array[TechniqueData] = []
	for technique_id in trainer.teachable_techniques:
		var technique := Content.technique(technique_id)
		if technique != null and technique.tier <= technique_tier(trainer):
			result.append(technique)
	return result


static func is_region_open(profile: OwnerProfile, region_id: String) -> bool:
	var region := Content.region(region_id)
	return region != null and profile.is_flag_set(region.unlock_flag)


## Mentors the Keeper could recruit now (trainer board).
static func recruitable(profile: OwnerProfile) -> Array[TrainerData]:
	var result: Array[TrainerData] = []
	for trainer: TrainerData in Content.list("trainers"):
		if profile.owned_trainers.has(trainer.id) or trainer.story_recruit:
			continue
		if is_region_open(profile, trainer.region_id):
			result.append(trainer)
	return result


## Mentors known to exist in regions the Keeper has not reached yet.
static func rumored(profile: OwnerProfile) -> Array[TrainerData]:
	var result: Array[TrainerData] = []
	for trainer: TrainerData in Content.list("trainers"):
		if not profile.owned_trainers.has(trainer.id) and not is_region_open(profile, trainer.region_id):
			result.append(trainer)
	return result


static func owned(profile: OwnerProfile) -> Array[TrainerData]:
	var result: Array[TrainerData] = []
	for trainer_id in profile.owned_trainers:
		var trainer := Content.trainer(trainer_id)
		if trainer != null:
			result.append(trainer)
	return result


static func active(profile: OwnerProfile) -> Array[TrainerData]:
	var result: Array[TrainerData] = []
	for trainer_id in profile.active_trainers:
		var trainer := Content.trainer(trainer_id)
		if trainer != null:
			result.append(trainer)
	return result


static func is_active(profile: OwnerProfile, trainer_id: String) -> bool:
	return profile.active_trainers.has(trainer_id)


static func free_slots(profile: OwnerProfile) -> int:
	return maxi(profile.trainer_slots() - profile.active_trainers.size(), 0)


## Adds a mentor to the lodge roster. Activates them if a slot is free.
## `free` is used for story recruits.
static func recruit(profile: OwnerProfile, trainer_id: String, free: bool = false) -> String:
	var trainer := Content.trainer(trainer_id)
	if trainer == null:
		return "Unknown mentor."
	if profile.owned_trainers.has(trainer_id):
		return "%s already works with your lodge." % trainer.display_name
	if not free and not profile.spend(trainer.recruit_cost):
		return "You need %d coins to sign a contract with %s." % [trainer.recruit_cost, trainer.display_name]
	profile.owned_trainers.append(trainer_id)
	if free_slots(profile) > 0:
		profile.active_trainers.append(trainer_id)
	profile.changed.emit()
	return ""


static func activate(profile: OwnerProfile, trainer_id: String) -> String:
	if not profile.owned_trainers.has(trainer_id):
		return "That mentor has not joined your lodge."
	if profile.active_trainers.has(trainer_id):
		return ""
	if free_slots(profile) <= 0:
		return "Your lodge can keep only %d active mentor%s. Replace one, or grow your lodge's reputation." % [
				profile.trainer_slots(), "" if profile.trainer_slots() == 1 else "s"]
	profile.active_trainers.append(trainer_id)
	profile.changed.emit()
	return ""


static func deactivate(profile: OwnerProfile, trainer_id: String) -> String:
	if not profile.active_trainers.has(trainer_id):
		return "That mentor is not active."
	profile.active_trainers.erase(trainer_id)
	profile.changed.emit()
	return ""


## Swaps an active mentor for an owned, inactive one.
static func replace(profile: OwnerProfile, old_id: String, new_id: String) -> String:
	if not profile.active_trainers.has(old_id):
		return "That mentor is not active."
	if not profile.owned_trainers.has(new_id) or profile.active_trainers.has(new_id):
		return "That mentor cannot take the slot."
	profile.active_trainers[profile.active_trainers.find(old_id)] = new_id
	profile.changed.emit()
	return ""


## Bond grows with sessions taught (shown on the trainer card).
static func bond_level(profile: OwnerProfile, trainer_id: String) -> int:
	var sessions := int(profile.trainer_sessions.get(trainer_id, 0))
	return mini(sessions / 5, 5)
