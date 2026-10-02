extends LodgePanel
## Equipment Hall: weapons, armor and accessories with projected combat
## effects before equipping (mechanics §65, story §30).

const SLOTS := [["Weapons", "weapon"], ["Armor", "armor"], ["Accessories", "accessory"]]

var _slot := "weapon"


func build(container: VBoxContainer) -> void:
	set_title("Equipment Hall")
	set_tabs(SLOTS, _slot, func(slot: String) -> void:
		_slot = slot
		rebuild())
	var champion := Game.champion()
	var profile := Game.profile
	var equipped := EquipmentSystem.equipped_id(champion, _slot)
	var current := card("Equipped", "Every champion can use every weapon. Mastery determines how well.")
	var item := Content.equipment(equipped) if not equipped.is_empty() else null
	current.add_child(UiKit.label(item.display_name if item else "Nothing equipped"))
	if item != null:
		current.add_child(UiKit.label(item.description, "DimLabel", true))
		current.add_child(_effects_label(champion, ""))
		var unequip := UiKit.button("Unequip", func() -> void:
			EquipmentSystem.unequip(champion, _slot)
			Game.save())
		current.add_child(unequip)
	var owned := EquipmentSystem.owned(profile, _slot)
	var others := owned.filter(func(i: EquipmentData) -> bool: return i.id != equipped)
	if not others.is_empty():
		card("Owned")
		for entry: EquipmentData in others:
			_item_card(champion, entry, "equip")
	var market := EquipmentSystem.for_sale(profile, _slot)
	if not market.is_empty():
		card("Valley Market")
		for entry in market:
			_item_card(champion, entry, "buy")
	var later := Content.list(EquipmentSystem.category_for_slot(_slot)).filter(func(i: EquipmentData) -> bool:
		return not i.available or not TrainerManager.is_region_open(profile, i.region_id) and not i.region_id.is_empty())
	if not later.is_empty():
		var names := PackedStringArray()
		for entry: EquipmentData in later:
			var region := Content.region(entry.region_id)
			names.append("%s (%s)" % [entry.display_name, region.display_name if region else "?"])
		card("Found further along the journey", ", ".join(names))


func _item_card(champion: Champion, item: EquipmentData, mode: String) -> void:
	var column := card(item.display_name, item.description)
	if item is WeaponData:
		var weapon := item as WeaponData
		var rank := champion.skills.get_rank("weapon:" + weapon.weapon_type)
		column.add_child(UiKit.label("%s · %s mastery: %s" % [GameEnums.WEAPON_TYPE_NAMES[weapon.weapon_type],
				champion.name, GameEnums.rank_name(rank) if rank > 0 else "Unlearned"], "DimLabel"))
	elif item is ArmorData:
		column.add_child(UiKit.label("%s armor" % GameEnums.ARMOR_WEIGHT_NAMES[(item as ArmorData).weight_class], "DimLabel"))
	column.add_child(_effects_label(champion, item.id))
	if mode == "equip":
		column.add_child(UiKit.primary_button("Equip", _equip.bind(item.id)))
	else:
		var buy := UiKit.primary_button("Buy (◉ %d)" % item.price, _buy.bind(item.id))
		buy.disabled = not Game.profile.can_afford(item.price)
		column.add_child(buy)


## "Attack 24 → 31 ▲" style projection against the current loadout.
func _effects_label(champion: Champion, item_id: String) -> RichTextLabel:
	var projection := EquipmentSystem.projection(champion, _slot, item_id) if not item_id.is_empty() else {}
	var stats := CombatStats.for_champion(champion).summary()
	var parts := PackedStringArray()
	for key: String in stats:
		var value: float = stats[key]
		if projection.is_empty():
			parts.append("%s %s" % [key, _fmt(key, value)])
			continue
		var projected: float = projection[key]["projected"]
		var delta := projected - value
		if absf(delta) < 0.01:
			continue
		var better := delta > 0.0
		parts.append("%s %s → [color=%s]%s %s[/color]" % [key, _fmt(key, value),
				"#8cc46f" if better else "#d9674e", _fmt(key, projected), "▲" if better else "▼"])
	if parts.is_empty():
		parts.append("No change to combat numbers")
	return UiKit.rich("  ·  ".join(parts))


func _fmt(key: String, value: float) -> String:
	match key:
		"Attack Speed", "Mobility", "Range":
			return "%.2f" % value
		"Defense":
			return "%d%%" % roundi(value)
	return "%d" % roundi(value)


func _equip(item_id: String) -> void:
	var error := EquipmentSystem.equip(Game.champion(), Game.profile, item_id)
	if error.is_empty():
		Sfx.play("ui_confirm")
		if _slot == "weapon":
			Game.set_flag("equipped_weapon")
		Game.save()
	else:
		toast(error, UiTheme.BAD)


func _buy(item_id: String) -> void:
	var error := EquipmentSystem.buy(Game.profile, item_id)
	if error.is_empty():
		Sfx.play("coins")
		toast("Bought %s." % Content.equipment(item_id).display_name, UiTheme.GOOD)
		Game.save()
	else:
		toast(error, UiTheme.BAD)
