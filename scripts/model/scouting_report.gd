class_name ScoutingReport
extends RefCounted
## What a Keeper can learn about a combatant before choosing to fight it.
##
## Every entry is derived from the same CombatStats the battle runs on, so the
## report never misleads — but it is deliberately partial and descriptive:
## bands like "High" and named threats, never exact stats, ranks or a win
## chance. Health, attack speed, evasion, endurance, Skill Matrix ranks and
## tendencies are only hinted at through threats and openings.

const BAND_NAMES: Array[String] = ["Very Low", "Low", "Medium", "High", "Very High"]

## Upper bounds of the first four bands for each derived axis.
## Strength: heavy stagger power + knockback x 10 (physical force).
const STRENGTH_BANDS: Array[float] = [25.0, 40.0, 60.0, 125.0]
## Defense: mitigation % + stagger resistance.
const DEFENSE_BANDS: Array[float] = [12.0, 20.0, 30.0, 45.0]
## Mobility: (move speed + dodge distance) x 8.
const MOBILITY_BANDS: Array[float] = [50.0, 62.0, 74.0, 86.0]

## Reach (metres) separating Short / Medium / Long range.
const RANGE_MEDIUM := 1.6
const RANGE_LONG := 3.5

const HEAVY_STAGGER_FORCE := 60.0
const STRONG_KNOCKBACK := 2.5
const FAST_ACTION_SPEED := 1.35
const LONG_HEAVY_RECOVERY := 0.9
const LOW_MAX_STAMINA := 108.0
const RELENTLESS_AGGRESSION := 0.65

var name := ""
var title := ""
var bio := ""
var animal := ""
var movement := ""
var capability := ""
var weapon := ""
var weapon_family := ""
var armor := ""
var armor_weight := ""
var magic := ""
var magic_school := ""
var strength := ""
var defense := ""
var mobility := ""
var combat_range := ""
## What this combatant does well that the player must respect.
var threats := PackedStringArray()
## Habits and limits the player can exploit.
var openings := PackedStringArray()
## The derived numbers behind the bands. For comparisons only — never shown.
var combat: CombatStats


static func for_opponent(opponent: OpponentData) -> ScoutingReport:
	var ability := Content.ability(opponent.magic_ability_id)
	if ability != null and opponent.rank_of("magic:" + ability.school) < ability.required_rank:
		ability = null  # not learned well enough to use
	var armor_data := Content.armor(opponent.armor_id) if not opponent.armor_id.is_empty() else null
	var report := describe_build(CombatStats.for_opponent(opponent), Content.weapon(opponent.weapon_id),
			armor_data, ability, Content.animal(opponent.animal_id))
	report.name = opponent.display_name
	report.title = opponent.title
	report.bio = opponent.bio
	var score := Champion.score_capability(opponent.rank_of, opponent.techniques.size())
	report.capability = Champion.CAPABILITY_NAMES[Champion.capability_rank_for(score)]
	if opponent.aggression >= RELENTLESS_AGGRESSION:
		report.threats.append("Relentless pressure")
	return report


## The Keeper's own champion described the same way, so the two sides can be
## compared band for band. `overrides` previews a different build:
## {"weapon_id", "armor_id", "accessory_id", "ability_id"}.
static func for_champion(champion: Champion, overrides: Dictionary = {}) -> ScoutingReport:
	var weapon_id: String = overrides.get("weapon_id", champion.weapon_id)
	var armor_id: String = overrides.get("armor_id", champion.armor_id)
	var ability := Content.ability(overrides.get("ability_id", champion.equipped_ability))
	if ability != null and not EquipmentSystem.can_use_ability(champion, ability):
		ability = null
	var report := describe_build(CombatStats.for_champion(champion, overrides),
			Content.weapon(weapon_id) if not weapon_id.is_empty() else null,
			Content.armor(armor_id) if not armor_id.is_empty() else null, ability, champion.data())
	report.name = champion.name
	report.capability = champion.capability_name()
	return report


## The build-dependent part of a report. Species-agnostic: movement and soft
## traits come from `animal`, everything else from the derived combat numbers.
static func describe_build(combat: CombatStats, weapon_data: WeaponData, armor_data: ArmorData,
		ability: MagicAbilityData, animal_data: AnimalData) -> ScoutingReport:
	var report := ScoutingReport.new()
	report.combat = combat
	if animal_data != null:
		report.animal = animal_data.display_name
		report.movement = GameEnums.MOVEMENT_TYPE_NAMES[animal_data.movement_type]
	report.weapon = weapon_data.display_name if weapon_data != null else "Unarmed"
	report.weapon_family = GameEnums.WEAPON_TYPE_NAMES.get(weapon_data.weapon_type, "") \
			if weapon_data != null else "Unarmed"
	report.armor = armor_data.display_name if armor_data != null else "None"
	report.armor_weight = GameEnums.ARMOR_WEIGHT_NAMES[armor_data.weight_class] if armor_data != null else "None"
	report.magic = ability.display_name if ability != null else "None"
	report.magic_school = GameEnums.MAGIC_SCHOOL_NAMES.get(ability.school, "") if ability != null else "None"

	var force := force_of(combat)
	var guard := guard_of(combat)
	var agility := mobility_of(combat)
	var reach := reach_of(combat, ability)
	report.strength = band(force, STRENGTH_BANDS)
	report.defense = band(guard, DEFENSE_BANDS)
	report.mobility = band(agility, MOBILITY_BANDS)
	report.combat_range = "Long" if reach >= RANGE_LONG else ("Medium" if reach >= RANGE_MEDIUM else "Short")

	if force >= HEAVY_STAGGER_FORCE:
		report.threats.append("Heavy stagger")
	if combat.knockback_power >= STRONG_KNOCKBACK:
		report.threats.append("Strong knockback")
	if combat.action_speed >= FAST_ACTION_SPEED:
		report.threats.append("Fast combos")
	if ability != null:
		report.threats.append(_ability_threat(ability, report.magic_school))
	if guard >= DEFENSE_BANDS[2]:
		report.threats.append("Tough guard")
	if agility >= MOBILITY_BANDS[3]:
		report.threats.append("Hard to pin down")

	if combat.heavy_recovery >= LONG_HEAVY_RECOVERY:
		report.openings.append("Long recovery after heavy swings")
	if agility < MOBILITY_BANDS[1]:
		report.openings.append("Slow to reposition")
	if guard < DEFENSE_BANDS[1]:
		report.openings.append("Light defenses")
	if combat.max_stamina < LOW_MAX_STAMINA:
		report.openings.append("Tires quickly")
	if force < STRENGTH_BANDS[0]:
		report.openings.append("Little stagger power")
	if reach < RANGE_LONG:
		report.openings.append("No ranged options")
	return report


static func force_of(combat: CombatStats) -> float:
	return combat.heavy_stagger_power + combat.knockback_power * 10.0


static func guard_of(combat: CombatStats) -> float:
	return combat.mitigation * 100.0 + (1.0 - combat.stagger_taken) * 30.0


static func mobility_of(combat: CombatStats) -> float:
	return (combat.move_speed + combat.dodge_distance) * 8.0


## Farthest distance this build can hurt from: weapon reach, or an Art that
## strikes at range.
static func reach_of(combat: CombatStats, ability: MagicAbilityData) -> float:
	var reach := combat.attack_range
	if ability != null and ability.effect in [MagicAbilityData.Effect.PROJECTILE, MagicAbilityData.Effect.CONE_PUSH]:
		reach = maxf(reach, ability.cast_range)
	return reach


static func band(value: float, bounds: Array[float]) -> String:
	for i in bounds.size():
		if value < bounds[i]:
			return BAND_NAMES[i]
	return BAND_NAMES[bounds.size()]


static func _ability_threat(ability: MagicAbilityData, school_name: String) -> String:
	match ability.effect:
		MagicAbilityData.Effect.PROJECTILE:
			return "%s attacks from range" % school_name
		MagicAbilityData.Effect.CONE_PUSH:
			return "%s push at mid range" % school_name
		MagicAbilityData.Effect.NOVA:
			return "%s burst up close" % school_name
		MagicAbilityData.Effect.DASH:
			return "Sudden %s dash" % school_name
	return "%s Arts" % school_name


## Ordered label -> text pairs for an opponent preview. The fight adds its
## own context (arena, reason, rewards) around these.
func fields() -> Dictionary:
	return {
		"Opponent": name,
		"Animal": animal,
		"Movement": movement,
		"Capability": capability,
		"Weapon": weapon_family,
		"Armor": armor_weight,
		"Magic": magic_school,
		"Strength": strength,
		"Defense": defense,
		"Mobility": mobility,
		"Range": combat_range,
	}
