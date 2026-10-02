class_name GameConfig
extends Resource
## Every balance number that designers may want to tune lives here.
##
## Defaults are defined in code; `res://data/config/game_config.tres` can
## override any of them from the inspector without touching gameplay scripts.

@export_group("Owner / Lodge")
## Owner level -> active mentorship slots. Keys must be ascending.
@export var trainer_slot_levels: Dictionary = {1: 1, 5: 2, 10: 3, 15: 4, 20: 5}
@export var max_active_trainers: int = 5
@export var owner_xp_base: int = 60
@export var owner_xp_per_level: int = 40
@export var owner_max_level: int = 30
## Story names for lodge growth, indexed by slot count - 1.
@export var lodge_titles: PackedStringArray = [
	"Beginning Lodge", "Growing Lodge", "Established Lodge", "Recognized Lodge", "Renowned Lodge",
]
@export var starting_coins: int = 300

@export_group("Animal level")
@export var animal_xp_base: int = 80
@export var animal_xp_per_level: int = 35
@export var animal_max_level: int = 50

@export_group("Experience")
## Experience needed for the first growth event of a track.
@export var growth_threshold_base: float = 80.0
## Each growth event raises the next threshold by this factor.
@export var growth_threshold_scale: float = 1.18
## Stat points gained per natural growth event (before potential limits).
@export var growth_stat_amount: float = 2.0
## Familiarity progress gained per weapon/magic growth event.
@export var growth_familiarity_amount: float = 25.0
## Difficulty ratio (opponent power / champion power) -> experience multiplier.
@export var difficulty_bands: Array[Vector2] = [
	Vector2(0.0, 0.75), Vector2(0.85, 1.0), Vector2(1.12, 1.25), Vector2(1.35, 1.5),
]
## Each repetition of the same event key multiplies its value by this factor.
@export var repeat_decay: float = 0.82
@export var repeat_floor: float = 0.08
## Repetition memory halves after this many seconds without that event.
@export var repeat_memory_seconds: float = 6.0
## Hard cap of experience per track per battle (before difficulty).
@export var per_battle_track_cap: float = 70.0
## Below this fraction of remaining potential, experience gain slows down.
@export var potential_slowdown_start: float = 0.8
@export var potential_min_factor: float = 0.15
## Natural familiarity can raise weapon/magic/fundamental skills only this far;
## higher mastery needs a trainer (mechanics §19).
@export var natural_rank_cap: int = 3
## Skill progress added to the related fundamental on each growth event.
@export var growth_skill_progress: float = 22.0

@export_group("Skill progress")
## Progress needed to advance one rank (multiplied by the next rank index).
@export var skill_progress_per_rank: float = 100.0
## Stat value thresholds used to describe a stat with a rank name.
@export var stat_rank_thresholds: PackedFloat32Array = [0.0, 1.0, 25.0, 40.0, 55.0, 70.0, 88.0]

@export_group("Training")
@export var training_energy_cost: int = 20
@export var training_base_coin_cost: int = 40
@export var training_coin_cost_per_rank: int = 25
@export var training_base_progress: float = 45.0
@export var training_stat_points: float = 3.0
@export var secondary_discipline_factor: float = 0.6
## Fraction of matching banked experience that a trainer converts per session.
@export var experience_conversion_rate: float = 0.5
## Bonus progress per converted experience point.
@export var experience_conversion_value: float = 0.35

@export_group("Trainer rarity")
@export var rarity_efficiency: PackedFloat32Array = [1.0, 1.15, 1.3, 1.5, 1.75]
## Highest rank a trainer of each rarity can teach.
@export var rarity_rank_cap: PackedInt32Array = [3, 4, 5, 6, 6]
## Highest stat value a trainer of each rarity can develop.
@export var rarity_stat_cap: PackedFloat32Array = [60.0, 70.0, 80.0, 90.0, 100.0]
## Highest technique tier a trainer of each rarity can teach (0 = none).
@export var rarity_technique_tier: PackedInt32Array = [0, 1, 2, 3, 3]
## Whether trainers of each rarity also teach their secondary discipline.
@export var rarity_secondary: Array[bool] = [false, true, true, true, true]
## Number of trait slots for each rarity.
@export var rarity_trait_slots: PackedInt32Array = [0, 1, 1, 2, 2]

@export_group("Energy / Happiness")
@export var max_energy: int = 100
@export var max_happiness: int = 100
@export var battle_energy_cost: int = 25
@export var passive_energy_regen_seconds: float = 180.0
@export var short_rest_energy: int = 25
@export var short_rest_cooldown_seconds: float = 300.0
@export var care_coin_cost: int = 40
@export var care_energy: int = 60
@export var care_happiness: int = 12
@export var knockout_recovery_seconds: float = 600.0
@export var happiness_win: int = 6
@export var happiness_loss: int = -4
@export var happiness_loss_streak_extra: int = -3
@export var happiness_training: int = 2
@export var happiness_overtraining: int = -6
## Training while energy is below this value counts as overtraining.
@export var overtraining_energy_threshold: int = 30
## Happiness -> training efficiency multiplier at 0 and at max happiness.
@export var happiness_training_range: Vector2 = Vector2(0.85, 1.1)

@export_group("Combat")
@export var base_health: float = 260.0
@export var health_per_point: float = 6.0
@export var base_stamina: float = 60.0
@export var stamina_per_endurance: float = 0.9
@export var stamina_regen_base: float = 14.0
@export var stamina_regen_per_endurance: float = 0.16
@export var stamina_regen_delay: float = 0.6
@export var exhausted_duration: float = 1.8
@export var exhausted_speed_factor: float = 0.55
@export var base_move_speed: float = 4.2
@export var move_speed_per_agility: float = 0.022
@export var sprint_factor: float = 1.45
@export var sprint_stamina_per_second: float = 12.0
@export var dodge_stamina: float = 16.0
@export var dodge_base_distance: float = 3.0
@export var dodge_distance_per_evasion: float = 0.02
@export var dodge_iframe_seconds: float = 0.26
@export var block_stamina_per_second: float = 4.0
@export var block_damage_factor: float = 0.25
@export var defense_mitigation_per_point: float = 0.0045
@export var perfect_window_seconds: float = 0.18
