class_name RegionData
extends Resource
## A region of the world map (story §7, §23).

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var chapter: int = 1
## Flag that opens the region ("" = open from the start).
@export var unlock_flag: String = ""
@export var map_position: Vector2 = Vector2.ZERO
@export var difficulty: String = "Gentle"
@export var color: Color = Color("6f9a52")
## What the region will introduce, shown before it unlocks.
@export var features: PackedStringArray = []
@export var sort_order: int = 0
