class_name EquipmentData
extends Resource
## Shared fields for anything a champion can equip.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Flat stat changes while equipped (e.g. {"agility": -4}).
@export var stat_modifiers: Dictionary = {}
@export var price: int = 0
## Region whose market sells it. Empty = given by story only.
@export var region_id: String = "home_valley"
## False for items whose combat behaviour belongs to a later milestone.
@export var available: bool = true
@export var sort_order: int = 0


func slot() -> String:
	return ""
