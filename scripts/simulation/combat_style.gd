class_name CombatStyle
extends RefCounted
## How a build wants to fight, read from its gear and body — never from its
## species. The decision layer uses the style to choose range, positioning
## and which attacks to favour, so changing a weapon visibly changes how a
## champion fights:
##
## - heavy    (hyper-armored heavy weapons): close in, heavy blows, stagger,
##            pressure guards.
## - agile    (flanking weapons or a very agile body in light armor): keep
##            moving, circle for the flank, avoid trades, punish openings,
##            dodge.
## - ranged   (ranged weapons): hold distance, shoot, back off when closed on.
## - balanced (everything else, e.g. the sword): a mix.

const HEAVY := "heavy"
const AGILE := "agile"
const RANGED := "ranged"
const BALANCED := "balanced"

## Distance a ranged build tries to keep.
const RANGED_DISTANCE := 7.0


static func of(spec: CombatantSpec) -> String:
	var weapon := spec.weapon
	if weapon != null and weapon.projectile_speed > 0.0:
		return RANGED
	if weapon != null and weapon.heavy_hyper_armor:
		return HEAVY
	var light_armor := spec.armor == null or spec.armor.weight_class == GameEnums.ArmorWeight.LIGHT
	if weapon != null and weapon.flank_bonus > 0.0:
		return AGILE
	if light_armor and spec.get_stat("agility") >= 70.0 and spec.get_stat("agility") > spec.get_stat("strength") + 15.0:
		return AGILE
	return BALANCED


## Where this build wants to stand from its target (centre to centre).
static func preferred_range(spec: CombatantSpec) -> float:
	var reach := spec.derived.attack_range + CombatantState.BODY_RADIUS
	match of(spec):
		RANGED:
			return RANGED_DISTANCE
		AGILE:
			return reach * 0.95
		HEAVY:
			return reach * 0.75
	return reach * 0.85


## Tendencies a champion fights with when it has no profile of its own,
## shaped by its build.
static func tendencies_for(spec: CombatantSpec) -> Dictionary:
	var result := {"aggression": 0.55, "caution": 0.4, "mobility": 0.4, "heavy_chance": 0.25,
			"magic_chance": 0.3 if spec.ability != null else 0.0, "preferred_range": preferred_range(spec)}
	match of(spec):
		HEAVY:
			result.merge({"aggression": 0.6, "mobility": 0.2, "heavy_chance": 0.55}, true)
		AGILE:
			result.merge({"aggression": 0.45, "caution": 0.5, "mobility": 0.85, "heavy_chance": 0.1}, true)
		RANGED:
			result.merge({"aggression": 0.5, "caution": 0.55, "mobility": 0.7, "heavy_chance": 0.15}, true)
	return result
