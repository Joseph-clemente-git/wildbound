class_name AnimalData
extends Resource
## Species definition. Nothing in gameplay branches on the species id; every
## difference between animals comes from these fields (mechanics §5-7).

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var movement_type: GameEnums.MovementType = GameEnums.MovementType.GROUND
## Optional Blender-imported body. When empty, `visual_id` picks a procedural rig.
@export var model_scene: PackedScene
@export var visual_id: String = "procedural_dog"
## Default colours for the body (keys understood by the visual).
@export var palette: Dictionary = {}

@export_group("Natural attributes")
## Starting value for every stat in GameEnums.STATS (0-100 scale).
@export var base_stats: Dictionary = {}
## Developmental ceiling per stat, plus "magic" for Aether Arts.
@export var potential: Dictionary = {}

## Natural foundation of the Skill Matrix: ranks the species starts with.
@export var starting_skills: Dictionary = {}

@export_group("Balance profile")
@export var strengths: PackedStringArray = []
@export var weaknesses: PackedStringArray = []
@export var counterplay: PackedStringArray = []
## Soft combat modifiers (1.0 = neutral). Known keys:
## knockback_taken, stagger_taken, dodge_efficiency, stamina_efficiency,
## turn_speed, block_efficiency.
@export var combat_traits: Dictionary = {}

@export_group("Presentation")
@export var default_names: PackedStringArray = []
@export var personality: String = ""
@export var sort_order: int = 0

const DESCRIPTORS := [[25.0, "Very Low"], [35.0, "Low"], [47.0, "Medium"], [60.0, "High"], [999.0, "Very High"]]


func get_base(stat: String) -> float:
	return float(base_stats.get(stat, 30.0))


func get_potential(stat: String) -> float:
	return float(potential.get(stat, 100.0))


func get_trait(key: String) -> float:
	return float(combat_traits.get(key, 1.0))


## "Medium", "High"... used when presenting natural tendencies.
static func describe_value(value: float) -> String:
	for entry: Array in DESCRIPTORS:
		if value < entry[0]:
			return entry[1]
	return "Very High"


## Checks the balance rule: strengths need weaknesses and counterplay.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id.is_empty():
		problems.append("missing id")
	for stat: String in GameEnums.STATS:
		if not base_stats.has(stat):
			problems.append("missing base stat " + stat)
		elif get_base(stat) > get_potential(stat):
			problems.append("base %s above potential" % stat)
	if strengths.is_empty() or weaknesses.is_empty() or counterplay.is_empty():
		problems.append("every animal needs strengths, weaknesses and counterplay")
	return problems
