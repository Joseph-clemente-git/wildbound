class_name ArmorData
extends EquipmentData
## Armor changes playstyle: light favours mobility, heavy favours defense.

@export var weight_class: GameEnums.ArmorWeight = GameEnums.ArmorWeight.MEDIUM
@export var defense_bonus: float = 0.0
@export var move_speed_factor: float = 1.0
@export var dodge_distance_factor: float = 1.0
## Multiplier on all stamina costs.
@export var stamina_cost_factor: float = 1.0
## 0..1 reduction of stagger build-up.
@export var stagger_resist: float = 0.0
## 0..1 reduction of knockback distance.
@export var knockback_resist: float = 0.0


func slot() -> String:
	return "armor"
