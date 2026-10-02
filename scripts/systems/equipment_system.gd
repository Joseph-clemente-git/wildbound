class_name EquipmentSystem
extends RefCounted
## Buying and equipping weapons, armor, accessories and Aether Arts
## (mechanics §41-46, prompts 16-19). Every animal can use every weapon and
## learn every school; availability only depends on region and story.


static func category_for_slot(slot: String) -> String:
	match slot:
		"weapon":
			return "weapons"
		"armor":
			return "armor"
	return "accessories"


static func equipped_id(champion: Champion, slot: String) -> String:
	match slot:
		"weapon":
			return champion.weapon_id
		"armor":
			return champion.armor_id
	return champion.accessory_id


## Items of a slot the Keeper owns.
static func owned(profile: OwnerProfile, slot: String) -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for item: EquipmentData in Content.list(category_for_slot(slot)):
		if profile.owns_item(item.id):
			result.append(item)
	return result


## Items of a slot the lodge's markets sell right now.
static func for_sale(profile: OwnerProfile, slot: String) -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for item: EquipmentData in Content.list(category_for_slot(slot)):
		if profile.owns_item(item.id) or not item.available or item.price <= 0 or item.region_id.is_empty():
			continue
		if TrainerManager.is_region_open(profile, item.region_id):
			result.append(item)
	return result


static func buy(profile: OwnerProfile, item_id: String) -> String:
	var item := Content.equipment(item_id)
	if item == null or not item.available:
		return "That item is not available."
	if profile.owns_item(item_id):
		return "Already owned."
	if not profile.spend(item.price):
		return "You need %d coins." % item.price
	profile.add_item(item_id)
	return ""


static func equip(champion: Champion, profile: OwnerProfile, item_id: String) -> String:
	var item := Content.equipment(item_id)
	if item == null:
		return "Unknown item."
	if not profile.owns_item(item_id):
		return "You do not own %s." % item.display_name
	match item.slot():
		"weapon":
			champion.weapon_id = item_id
		"armor":
			champion.armor_id = item_id
		"accessory":
			champion.accessory_id = item_id
	champion.changed.emit()
	return ""


static func unequip(champion: Champion, slot: String) -> void:
	match slot:
		"weapon":
			champion.weapon_id = ""
		"armor":
			champion.armor_id = ""
		"accessory":
			champion.accessory_id = ""
	champion.changed.emit()


## Projected combat numbers if `item_id` were equipped (or slot emptied).
static func projection(champion: Champion, slot: String, item_id: String) -> Dictionary:
	var current := CombatStats.for_champion(champion).summary()
	var projected := CombatStats.for_champion(champion, {slot + "_id": item_id}).summary()
	var result := {}
	for key: String in current:
		result[key] = {"current": current[key], "projected": projected[key]}
	return result


# --- Aether Arts ---------------------------------------------------------------------

static func school_rank(champion: Champion, school: String) -> int:
	return champion.skills.get_rank("magic:" + school)


static func can_use_ability(champion: Champion, ability: MagicAbilityData) -> bool:
	return school_rank(champion, ability.school) >= ability.required_rank and ability.required_rank > 0 \
			and Content.school(ability.school).available


static func equip_ability(champion: Champion, ability_id: String) -> String:
	var ability := Content.ability(ability_id)
	if ability == null:
		return "Unknown Aether Art."
	if not can_use_ability(champion, ability):
		return "%s requires %s %s." % [ability.display_name,
				GameEnums.MAGIC_SCHOOL_NAMES[ability.school], GameEnums.rank_name(ability.required_rank)]
	champion.equipped_ability = ability_id
	champion.changed.emit()
	return ""


static func unequip_ability(champion: Champion) -> void:
	champion.equipped_ability = ""
	champion.changed.emit()
