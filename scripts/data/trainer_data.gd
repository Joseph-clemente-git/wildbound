class_name TrainerData
extends Resource
## A mentor: a person who has dedicated their life to a discipline. Trainers
## are universal — any trainer can train any champion (mechanics §32).
## Rarity scales training capability, never battle power.

@export var id: String = ""
@export var display_name: String = ""
## Discipline title, e.g. "Swordmaster", "Fire Mage".
@export var title: String = ""
@export var category: GameEnums.TrainerCategory = GameEnums.TrainerCategory.ATTRIBUTE
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
@export_multiline var description: String = ""
@export_multiline var greeting: String = ""

@export_group("Disciplines")
## Development targets taught at full strength ("stat:agility", "weapon:sword"...).
@export var primary_discipline: PackedStringArray = []
## Taught at reduced strength, only when the rarity supports it.
@export var secondary_discipline: PackedStringArray = []
## Trait ids from TrainerTraits.
@export var traits: PackedStringArray = []
## Personal skill on top of rarity (0.9 - 1.1).
@export var personal_efficiency: float = 1.0
@export var teachable_techniques: PackedStringArray = []

@export_group("Recruitment")
@export var region_id: String = "home_valley"
@export var recruit_cost: int = 0
## Joins the lodge through the story rather than the trainer board.
@export var story_recruit: bool = false
## How the mentor looks (ProceduralHumanVisual appearance keys).
@export var appearance: Dictionary = {}
@export var sort_order: int = 0


func teaches(target: String) -> bool:
	return primary_discipline.has(target) or secondary_discipline.has(target)


func is_primary(target: String) -> bool:
	return primary_discipline.has(target)


func discipline_label(targets: PackedStringArray) -> String:
	var names := PackedStringArray()
	for target in targets:
		names.append(SkillCatalog.target_name(target))
	return ", ".join(names)
