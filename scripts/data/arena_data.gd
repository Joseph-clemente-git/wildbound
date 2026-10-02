class_name ArenaData
extends Resource
## A trial ground. Size scales with battle format and movement needs.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var region_id: String = "home_valley"
@export var format: GameEnums.BattleFormat = GameEnums.BattleFormat.ONE_V_ONE
@export var radius: float = 11.0
@export var mood: String = "day"
@export var player_spawns: Array[Vector3] = [Vector3(0, 0, 5)]
@export var opponent_spawns: Array[Vector3] = [Vector3(0, 0, -5)]
## Obstacles: Vector4(x, z, radius, height) — rocks and standing stones.
@export var obstacles: Array[Vector4] = []
@export var ground_color_a: Color = Color(0.36, 0.5, 0.24)
@export var ground_color_b: Color = Color(0.44, 0.56, 0.28)
@export var banner_color: Color = Color("b8433a")
## Camera must stay within this distance of the arena centre.
@export var camera_limit: float = 16.0
@export var sort_order: int = 0


## What a Keeper notices about the ground before a fight, derived from its
## shape so every arena describes itself.
func features() -> PackedStringArray:
	var notes := PackedStringArray()
	if radius < 9.0:
		notes.append("Tight ring: little room to back away")
	elif radius < 14.0:
		notes.append("Medium ring: room to reposition")
	else:
		notes.append("Wide ground: space to keep distance")
	if obstacles.is_empty():
		notes.append("Open ground with no cover")
	elif obstacles.size() <= 4:
		notes.append("A few obstacles to step around")
	else:
		notes.append("Many obstacles breaking lines of attack")
	return notes
