class_name MagicAbilityData
extends Resource
## A castable Aether Art. Every ability has cost, cast time, recovery and
## counterplay; `effect` selects one of the generic combat behaviours.

enum Effect { PROJECTILE, CONE_PUSH, NOVA, DASH }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var school: String = "fire"
## Magic mastery rank needed to use it (GameEnums.Rank).
@export var required_rank: int = GameEnums.Rank.FOUNDATION
@export var effect: Effect = Effect.PROJECTILE
@export var stamina_cost: float = 20.0
@export var cast_time: float = 0.5
@export var recovery: float = 0.4
@export var cooldown: float = 2.5
@export var cast_range: float = 12.0
@export var damage: float = 30.0
@export var knockback: float = 1.0
@export var stagger: float = 10.0
## Projectile speed or dash distance, depending on effect.
@export var speed: float = 14.0
@export var radius: float = 0.4
@export var cone_degrees: float = 60.0
## Optional damage-over-time.
@export var burn_dps: float = 0.0
@export var burn_seconds: float = 0.0
## Optional slow on whoever it strikes (0.5 = half speed).
@export var slow_factor: float = 0.0
@export var slow_seconds: float = 0.0
## Optional ward on the caster: share of incoming damage turned aside.
@export var ward_factor: float = 0.0
@export var ward_seconds: float = 0.0
## Knocks a flier out of the air when it strikes it aloft (wind, control).
@export var grounds_fliers: bool = false
## Taking a hit while casting cancels the spell.
@export var interruptible: bool = true
@export_multiline var counterplay: String = ""
