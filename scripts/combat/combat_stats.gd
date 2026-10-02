class_name CombatStats
extends RefCounted
## Derived battle numbers for one combatant (mechanics §8, §41-49).
##
## Built purely from data — final stats, skill ranks, weapon, armor and the
## species' soft combat traits — so champions and opponents share one formula
## and the Equipment Hall can project the effect of a change before it is made.
## Skill ranks add small, capped refinements; they never dominate stats.

var max_health: float
var max_stamina: float
var stamina_regen: float
var move_speed: float
var turn_speed: float
var damage: float
var heavy_damage: float
var action_speed: float
var attack_range: float
var arc_degrees: float
var windup: float
var active: float
var recovery: float
var heavy_windup: float
var heavy_recovery: float
var combo_max: int
var attack_stamina: float
var heavy_stamina: float
var stagger_power: float
var heavy_stagger_power: float
var knockback_power: float
var guard_pressure: float
var mitigation: float
var block_factor: float
var block_drain: float
var poise: float
var stagger_taken: float
var knockback_taken: float
var dodge_distance: float
var dodge_iframes: float
var dodge_stamina: float
var dodge_recovery: float
var perfect_window: float
var exhaustion_seconds: float
var hit_recovery: float
var magic_cast_factor: float
var sprint_stamina: float


## `rank_of` is a Callable(target: String) -> int returning Skill Matrix ranks.
static func build(stats: Dictionary, rank_of: Callable, weapon: WeaponData, armor: ArmorData,
		animal: AnimalData) -> CombatStats:
	var c := Content.config
	var s := CombatStats.new()
	var stat := func(key: String) -> float: return float(stats.get(key, 30.0))
	var rank := func(target: String) -> int: return int(rank_of.call(target))
	var trait_of := func(key: String) -> float: return animal.get_trait(key) if animal != null else 1.0
	var weapon_rank := 0
	if weapon != null:
		weapon_rank = rank.call("weapon:" + weapon.weapon_type)
	var armor_move := armor.move_speed_factor if armor != null else 1.08
	var armor_stamina := armor.stamina_cost_factor if armor != null else 0.9
	var armor_defense := armor.defense_bonus if armor != null else 0.0
	var armor_dodge := armor.dodge_distance_factor if armor != null else 1.12

	s.max_health = c.base_health + stat.call("health") * c.health_per_point
	s.max_stamina = c.base_stamina + stat.call("endurance") * c.stamina_per_endurance + rank.call("skill:stamina") * 4.0
	s.stamina_regen = c.stamina_regen_base + stat.call("endurance") * c.stamina_regen_per_endurance \
			+ rank.call("skill:stamina_discipline") * 1.2
	var weight := weapon.weight if weapon != null else 1.0
	s.move_speed = (c.base_move_speed + stat.call("agility") * c.move_speed_per_agility) * armor_move \
			* (1.0 - maxf(weight - 2.0, 0.0) * 0.015) * (1.0 + rank.call("skill:movement") * 0.012)
	s.turn_speed = 10.0 * (0.8 + stat.call("agility") / 250.0) * trait_of.call("turn_speed")

	# Offense
	var base_damage := weapon.damage if weapon != null else 8.0
	var scaling := weapon.strength_scaling if weapon != null else 0.2
	s.damage = (base_damage * (1.0 + stat.call("attack") / 100.0) + stat.call("strength") * scaling * 0.3) \
			* (1.0 + rank.call("skill:attack") * 0.02 + weapon_rank * 0.015)
	s.heavy_damage = s.damage * (weapon.heavy_multiplier if weapon != null else 1.6) \
			* (1.0 + stat.call("strength") / 400.0)
	s.action_speed = (weapon.attack_speed if weapon != null else 1.2) * (0.85 + stat.call("attack_speed") / 200.0) \
			* (1.0 + weapon_rank * 0.02)
	s.attack_range = weapon.attack_range if weapon != null else 1.3
	s.arc_degrees = weapon.arc_degrees if weapon != null else 90.0
	s.windup = (weapon.windup if weapon != null else 0.2) / s.action_speed
	s.active = (weapon.active if weapon != null else 0.1)
	s.recovery = (weapon.recovery if weapon != null else 0.25) / s.action_speed
	s.heavy_windup = (weapon.heavy_windup if weapon != null else 0.45) / s.action_speed
	s.heavy_recovery = (weapon.heavy_recovery if weapon != null else 0.45) / s.action_speed
	s.combo_max = (weapon.combo_max if weapon != null else 2) + (1 if weapon_rank >= GameEnums.Rank.SKILLED else 0)
	var attack_cost_factor: float = armor_stamina * (1.0 - rank.call("skill:attack_control") * 0.03) \
			* (1.0 - weapon_rank * 0.02)
	s.attack_stamina = (weapon.stamina_cost if weapon != null else 7.0) * attack_cost_factor
	s.heavy_stamina = (weapon.heavy_stamina_cost if weapon != null else 16.0) * attack_cost_factor
	var strength_factor: float = 0.6 + stat.call("strength") / 100.0
	s.stagger_power = (weapon.stagger if weapon != null else 10.0) * strength_factor
	s.heavy_stagger_power = s.stagger_power * 1.9
	s.knockback_power = (weapon.knockback if weapon != null else 0.8) * (0.7 + stat.call("strength") / 120.0)
	s.guard_pressure = (weapon.guard_pressure if weapon != null else 0.8) * (0.8 + stat.call("strength") / 200.0)

	# Defense
	s.mitigation = clampf((stat.call("defense") + armor_defense) * c.defense_mitigation_per_point
			+ rank.call("skill:defense") * 0.01, 0.0, 0.6)
	s.block_factor = clampf(c.block_damage_factor - rank.call("skill:block") * 0.015
			- stat.call("defense") * 0.0005, 0.05, 0.6) / trait_of.call("block_efficiency")
	s.block_drain = c.block_stamina_per_second * (1.0 - rank.call("skill:block_control") * 0.05)
	s.poise = 40.0 + stat.call("defense") * 0.5
	var armor_stagger := armor.stagger_resist if armor != null else 0.0
	var armor_knockback := armor.knockback_resist if armor != null else 0.0
	s.stagger_taken = (1.0 - armor_stagger) * (1.0 - rank.call("skill:defense_control") * 0.03) \
			* trait_of.call("stagger_taken")
	s.knockback_taken = (1.0 - armor_knockback) * (1.0 - rank.call("skill:positioning") * 0.03) \
			* trait_of.call("knockback_taken")

	# Evasion
	s.dodge_distance = (c.dodge_base_distance + stat.call("evasion") * c.dodge_distance_per_evasion) \
			* armor_dodge * trait_of.call("dodge_efficiency")
	s.dodge_iframes = c.dodge_iframe_seconds + rank.call("skill:dodge") * 0.015
	s.dodge_stamina = c.dodge_stamina * armor_stamina * (1.0 - rank.call("skill:dodge_control") * 0.04) \
			/ trait_of.call("dodge_efficiency")
	s.dodge_recovery = maxf(0.34 - stat.call("evasion") * 0.0015, 0.12)
	s.perfect_window = c.perfect_window_seconds + rank.call("skill:timing") * 0.015
	s.exhaustion_seconds = c.exhausted_duration * (1.0 - rank.call("skill:recovery_control") * 0.06)
	s.hit_recovery = 0.35 * (1.0 - rank.call("skill:recovery") * 0.04)
	s.sprint_stamina = c.sprint_stamina_per_second * armor_stamina
	s.magic_cast_factor = 1.0
	return s


static func for_champion(champion: Champion, overrides: Dictionary = {}) -> CombatStats:
	var weapon_id: String = overrides.get("weapon_id", champion.weapon_id)
	var armor_id: String = overrides.get("armor_id", champion.armor_id)
	var accessory_id: String = overrides.get("accessory_id", champion.accessory_id)
	var stats := {}
	for stat: String in GameEnums.STATS:
		var value := champion.developed_stat(stat)
		for item_id: String in [weapon_id, armor_id, accessory_id]:
			var item := Content.equipment(item_id) if not item_id.is_empty() else null
			if item != null:
				value += float(item.stat_modifiers.get(stat, 0.0))
		stats[stat] = clampf(value, 1.0, 120.0)
	var weapon := Content.weapon(weapon_id) if not weapon_id.is_empty() else null
	var armor := Content.armor(armor_id) if not armor_id.is_empty() else null
	return build(stats, champion.rank_of, weapon, armor, champion.data())


static func for_opponent(opponent: OpponentData) -> CombatStats:
	var rank_of := func(target: String) -> int: return int(opponent.skills.get(target, GameEnums.Rank.FOUNDATION))
	return build(opponent.stats, rank_of, Content.weapon(opponent.weapon_id), Content.armor(opponent.armor_id),
			Content.animal(opponent.animal_id))


## Player-facing summary used by equipment previews (mechanics §65).
func summary() -> Dictionary:
	return {
		"Attack": damage,
		"Heavy": heavy_damage,
		"Attack Speed": action_speed,
		"Defense": mitigation * 100.0,
		"Mobility": move_speed,
		"Stamina": max_stamina,
		"Range": attack_range,
		"Stagger": stagger_power,
	}
