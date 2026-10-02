class_name CombatantSpec
extends RefCounted
## Everything the simulation needs to know about one combatant, frozen at the
## moment the battle starts. Champions and opponents become the same shape
## here, so the engine never asks what kind of animal or which side it is
## dealing with: movement comes from `movement_type`, soft traits from
## `animal`, and capability from stats, skills, gear and condition.
##
## A spec is a snapshot: later changes to the champion do not reach a battle
## that has already been set up.

## Fallback tendencies for keys a profile leaves out. Champions take theirs
## from their build (CombatStyle.tendencies_for).
const DEFAULT_TENDENCIES := {
	"aggression": 0.5, "caution": 0.4, "mobility": 0.4,
	"heavy_chance": 0.25, "magic_chance": 0.0, "preferred_range": 1.8,
}

var id := ""
var display_name := ""
## "champion" or "opponent" — for results and records only, never for combat.
var source := ""
var animal: AnimalData
var movement_type: int = GameEnums.MovementType.GROUND
var palette: Dictionary = {}

## Final stats: developed stats plus equipment modifiers (0-120 scale).
var stats: Dictionary = {}
## Skill Matrix: every skill, weapon and magic target -> rank.
var skills: Dictionary = {}
var techniques := PackedStringArray()
## Bouts this combatant has fought — lived combat experience.
var battle_experience := 0

var weapon: WeaponData
var armor: ArmorData
var accessory: AccessoryData
## The Aether Art it can actually use (null when none or not learned enough).
var ability: MagicAbilityData
var weapon_mastery: int = GameEnums.Rank.NONE
var magic_mastery: int = GameEnums.Rank.NONE

var energy := 100.0
var happiness := 70.0
var tendencies: Dictionary = {}

## Derived combat numbers — the same formula the previews read.
var derived: CombatStats


static func from_champion(champion: Champion) -> CombatantSpec:
	var spec := CombatantSpec.new()
	spec.id = champion.uid
	spec.display_name = champion.name
	spec.source = "champion"
	spec.animal = champion.data()
	spec.palette = champion.palette.duplicate()
	var developed := {}
	for stat: String in GameEnums.STATS:
		developed[stat] = champion.developed_stat(stat)
	var item_ids := [champion.weapon_id, champion.armor_id, champion.accessory_id]
	spec.stats = CombatStats.with_equipment(developed, item_ids)
	for target: String in SkillCatalog.all_skill_targets():
		spec.skills[target] = champion.skills.get_rank(target)
	spec.techniques = PackedStringArray(champion.techniques)
	spec.battle_experience = champion.wins + champion.losses
	spec.weapon = Content.weapon(champion.weapon_id) if not champion.weapon_id.is_empty() else null
	spec.armor = Content.armor(champion.armor_id) if not champion.armor_id.is_empty() else null
	spec.accessory = Content.accessory(champion.accessory_id) if not champion.accessory_id.is_empty() else null
	var ability := Content.ability(champion.equipped_ability)
	spec.ability = ability if ability != null and EquipmentSystem.can_use_ability(champion, ability) else null
	spec.energy = champion.energy
	spec.happiness = champion.happiness
	spec.refresh()
	# Champions fight the way their build suggests (CombatStyle).
	spec.tendencies = CombatStyle.tendencies_for(spec)
	return spec


static func from_opponent(opponent: OpponentData) -> CombatantSpec:
	var spec := CombatantSpec.new()
	spec.id = opponent.id
	spec.display_name = opponent.display_name
	spec.source = "opponent"
	spec.animal = Content.animal(opponent.animal_id)
	spec.palette = opponent.palette.duplicate()
	spec.stats = CombatStats.with_equipment(opponent.stats, opponent.equipment_ids())
	for target: String in SkillCatalog.all_skill_targets():
		spec.skills[target] = opponent.rank_of(target)
	spec.techniques = PackedStringArray(opponent.techniques)
	spec.battle_experience = opponent.battles_fought
	spec.weapon = Content.weapon(opponent.weapon_id) if not opponent.weapon_id.is_empty() else null
	spec.armor = Content.armor(opponent.armor_id) if not opponent.armor_id.is_empty() else null
	spec.accessory = Content.accessory(opponent.accessory_id) if not opponent.accessory_id.is_empty() else null
	var ability := Content.ability(opponent.magic_ability_id)
	spec.ability = ability if ability != null and opponent.rank_of("magic:" + ability.school) >= ability.required_rank else null
	spec.energy = opponent.energy
	spec.happiness = opponent.happiness
	for key: String in OpponentData.TENDENCIES:
		spec.tendencies[key] = opponent.tendency(key)
	spec.refresh()
	return spec


func rank_of(target: String) -> int:
	return int(skills.get(target, GameEnums.Rank.NONE))


func get_stat(stat: String) -> float:
	return float(stats.get(stat, 30.0))


func tendency(key: String) -> float:
	return float(tendencies.get(key, DEFAULT_TENDENCIES.get(key, 0.0)))


## Recomputes everything derived from the inputs (after a test or a
## designer tool changes stats, skills or gear on a spec).
func refresh() -> void:
	movement_type = animal.movement_type if animal != null else GameEnums.MovementType.GROUND
	weapon_mastery = rank_of("weapon:" + weapon.weapon_type) if weapon != null else GameEnums.Rank.NONE
	magic_mastery = rank_of("magic:" + ability.school) if ability != null else GameEnums.Rank.NONE
	derived = CombatStats.build(stats, rank_of, weapon, armor, animal)


## Plain data for logs, replays and determinism checks.
func to_dict() -> Dictionary:
	return {
		"id": id, "name": display_name, "source": source, "palette": palette.duplicate(),
		"animal": animal.id if animal != null else "", "movement": movement_type,
		"stats": stats.duplicate(), "skills": skills.duplicate(), "techniques": Array(techniques),
		"battle_experience": battle_experience,
		"weapon": weapon.id if weapon != null else "", "armor": armor.id if armor != null else "",
		"accessory": accessory.id if accessory != null else "", "ability": ability.id if ability != null else "",
		"weapon_mastery": weapon_mastery, "magic_mastery": magic_mastery,
		"energy": energy, "happiness": happiness, "tendencies": tendencies.duplicate(),
	}
