class_name OpponentData
extends Resource
## A rival champion met in trials. Behaviour is a data profile with optional
## phases so tutorial opponents can teach one mechanic at a time (story §20).

@export var id: String = ""
@export var display_name: String = ""
@export var title: String = ""
@export var animal_id: String = "humanoid_dog"
@export var palette: Dictionary = {}
@export var level: int = 1
## Final stats used in battle (0-100 scale).
@export var stats: Dictionary = {}
## Skill ranks by target id ("weapon:sword": 3...).
@export var skills: Dictionary = {}
@export var weapon_id: String = "sword_training"
@export var armor_id: String = "armor_light"
@export var magic_ability_id: String = ""

@export_group("Behaviour")
## 0..1 how often it chooses to attack when in range.
@export var aggression: float = 0.5
@export var block_skill: float = 0.3
@export var dodge_skill: float = 0.2
@export var heavy_chance: float = 0.25
@export var magic_chance: float = 0.0
## Seconds before reacting to the player's attacks.
@export var reaction_time: float = 0.35
## Multiplier on attack wind-ups (> 1 = more readable).
@export var telegraph: float = 1.0
@export var preferred_range: float = 1.8
## Phases ordered by threshold: [{"below": 0.7, "hint": "...", "aggression": 0.2, ...}]
@export var phases: Array[Dictionary] = []

@export_group("Story")
@export_multiline var intro_line: String = ""
@export_multiline var win_line: String = ""
@export_multiline var lose_line: String = ""
@export var sort_order: int = 0
