class_name WeaponData
extends EquipmentData
## Weapon behaviour is entirely data: the combat system reads these numbers,
## so a new weapon of an existing type needs no code (mechanics §41-42).

@export var weapon_type: String = "sword"

@export_group("Light attack")
@export var damage: float = 20.0
## Multiplier on action speed (1 = normal, < 1 slower).
@export var attack_speed: float = 1.0
@export var attack_range: float = 1.9
@export_range(10.0, 360.0) var arc_degrees: float = 100.0
@export var stamina_cost: float = 9.0
@export var windup: float = 0.22
@export var active: float = 0.12
@export var recovery: float = 0.3
@export var combo_max: int = 3

@export_group("Heavy attack")
@export var heavy_multiplier: float = 1.9
@export var heavy_stamina_cost: float = 20.0
@export var heavy_windup: float = 0.5
@export var heavy_recovery: float = 0.55

@export_group("Force")
@export var weight: float = 2.0
## Fraction of the Strength stat added to damage scaling.
@export var strength_scaling: float = 0.35
@export var stagger: float = 18.0
@export var knockback: float = 1.2
## Stamina drained from a blocking opponent per point of damage blocked.
@export var guard_pressure: float = 1.0

@export_group("Mastery")
## Techniques this weapon type participates in (for UI hints).
@export var techniques: PackedStringArray = []


func slot() -> String:
	return "weapon"
