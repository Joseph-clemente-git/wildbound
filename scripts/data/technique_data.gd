class_name TechniqueData
extends Resource
## Advanced technique unlocked by a combination of skills (mechanics §30).
## Prerequisites map a development target to a minimum rank, e.g.
## {"weapon:hammer": Rank.SKILLED, "stat:strength": Rank.SKILLED}.

enum Trigger { AFTER_BLOCK_ATTACK, HEAVY_VS_GUARD, MAGIC_DODGE, HEAVY_WITH_MAGIC }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## 1 = basic, 2 = advanced, 3 = master. Trainer rarity limits the tier taught.
@export var tier: int = 1
@export var prerequisites: Dictionary = {}
## Contextual combat trigger; techniques never need an extra button.
@export var trigger: Trigger = Trigger.AFTER_BLOCK_ATTACK
## Required equipped Aether school for magic-based techniques ("" = none).
@export var required_school: String = ""
@export var stamina_cost: float = 10.0
@export var power: float = 1.5
@export var coin_cost: int = 150
@export var sort_order: int = 0
