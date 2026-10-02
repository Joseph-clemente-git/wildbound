class_name TerrainRules
extends RefCounted
## How the ground under a combatant — and the air above it — changes what
## its body can do. Everything is keyed by MovementType and the Natural
## Foundation skills (Swimming, Flight), never by species, so any animal
## with a movement type gets these rules.
##
##                 land                      deep water
##   GROUND        normal                    slow, short dodges, poor recovery
##   SWIMMING      slow and short of breath  fast, long dodges, harder blows
##   AMPHIBIOUS    nearly normal             quick
##   FLYING        normal when grounded      flies over it
##
## Fliers cruise above melee reach where the arena has open air, paying
## stamina for it, and swoop down to strike — which is when they can be hit.
## Shots and wind still reach them aloft; a stagger or knockdown grounds
## them for a moment, and an exhausted flier must land. Swimming and Flight
## ranks ease every penalty and sharpen every edge.

const M := GameEnums.MovementType
const A := CombatantState.Action
const P := CombatantState.Phase

## Height a flier cruises at, and the height it strikes from.
const CRUISE_HEIGHT := 2.4
const SWOOP_HEIGHT := 0.4
## Vertical speed (m/s) diving into a swoop and climbing back.
const DIVE_SPEED := 10.0
const CLIMB_SPEED := 3.0
## Height difference melee can bridge.
const VERTICAL_REACH := 1.3
## Stamina per second spent staying aloft (eased by Flight).
const FLIGHT_DRAIN := 3.0
## Seconds a flier stays grounded after a stagger or knockdown.
const GROUNDED_SECONDS := 1.4
## Stamina share below which a flier lands, and above which it takes off again.
const LAND_BELOW := 0.15
const TAKE_OFF_ABOVE := 0.45


static func in_water(state: BattleState, fighter: CombatantState) -> bool:
	return fighter.elevation < 0.5 and state.layout.in_water(fighter.position)


static func skill(fighter: CombatantState, natural: String) -> int:
	return fighter.spec.rank_of("skill:" + natural)


## Movement speed multiplier.
static func speed_factor(state: BattleState, fighter: CombatantState) -> float:
	var swim := skill(fighter, "swimming")
	match fighter.spec.movement_type:
		M.FLYING:
			return 1.15 if fighter.elevation > 0.5 else (0.6 + swim * 0.05 if in_water(state, fighter) else 1.0)
		M.SWIMMING:
			return 1.25 + swim * 0.03 if in_water(state, fighter) else 0.72 + swim * 0.01
		M.AMPHIBIOUS:
			return 1.12 + swim * 0.02 if in_water(state, fighter) else 0.95
	return minf(0.62 + swim * 0.06, 0.9) if in_water(state, fighter) else 1.0


## Dodge distance multiplier.
static func dodge_factor(state: BattleState, fighter: CombatantState) -> float:
	var water := in_water(state, fighter)
	var swim := skill(fighter, "swimming")
	match fighter.spec.movement_type:
		M.SWIMMING:
			return 1.25 + swim * 0.03 if water else 0.8
		M.AMPHIBIOUS:
			return 1.1 if water else 0.95
		M.FLYING:
			return 1.1 if fighter.elevation > 0.5 else (0.7 if water else 1.0)
	return minf(0.75 + swim * 0.04, 0.9) if water else 1.0


## Recovery while aloft: wingbeats eat into every breath (Flight eases it).
const AIRBORNE_REGEN := 0.35


## Stamina recovery multiplier.
static func regen_factor(state: BattleState, fighter: CombatantState) -> float:
	if fighter.elevation > 0.5:
		return minf(AIRBORNE_REGEN + skill(fighter, "flight") * 0.05, 0.7)
	var water := in_water(state, fighter)
	match fighter.spec.movement_type:
		M.SWIMMING:
			return 1.2 if water else 0.85
		M.AMPHIBIOUS:
			return 1.1 if water else 1.0
	return 0.8 if water else 1.0


## Damage multiplier for blows struck from where the attacker stands.
static func damage_factor(state: BattleState, attacker: CombatantState) -> float:
	if attacker.spec.movement_type == M.SWIMMING and in_water(state, attacker):
		return 1.06 + skill(attacker, "swimming") * 0.01
	return 1.0


## Whether this combatant can take to the air here and now.
static func can_fly(state: BattleState, fighter: CombatantState) -> bool:
	return fighter.spec.movement_type == M.FLYING and state.layout.air_ceiling > CRUISE_HEIGHT \
			and fighter.grounded_time <= 0.0 and not fighter.is_exhausted() \
			and fighter.action not in [A.STAGGER, A.KNOCKDOWN, A.KO]


## Where a flier wants to be: low while it strikes, casts or recovers, high
## otherwise — and on the ground when it cannot or should not fly.
static func target_height(state: BattleState, fighter: CombatantState) -> float:
	if not can_fly(state, fighter) or fighter.resting:
		return 0.0
	if fighter.action in [A.ATTACK, A.HEAVY, A.CAST]:
		return SWOOP_HEIGHT
	return CRUISE_HEIGHT


## Moves a flier's height toward where it wants to be and manages landing
## to rest.
static func fly(state: BattleState, fighter: CombatantState, delta: float) -> void:
	if fighter.spec.movement_type != M.FLYING:
		fighter.elevation = 0.0
		return
	if fighter.grounded_time > 0.0:
		fighter.grounded_time = maxf(fighter.grounded_time - delta, 0.0)
	if fighter.resting and fighter.stamina_ratio() >= TAKE_OFF_ABOVE:
		fighter.resting = false
	elif not fighter.resting and fighter.elevation > 0.5 and fighter.stamina_ratio() < LAND_BELOW:
		fighter.resting = true
	var goal := target_height(state, fighter)
	var speed := DIVE_SPEED + skill(fighter, "flight") * 0.5 if goal < fighter.elevation else CLIMB_SPEED
	fighter.elevation = move_toward(fighter.elevation, goal, speed * delta)


## Stamina paid this tick to stay aloft (Flight eases it).
static func flight_cost(fighter: CombatantState, delta: float) -> float:
	if fighter.elevation <= 0.5:
		return 0.0
	return FLIGHT_DRAIN * clampf(1.0 - skill(fighter, "flight") * 0.1, 0.4, 1.0) * delta


## Whether a blow can bridge the height between two combatants.
static func vertical_reach(attacker: CombatantState, target: CombatantState, extra: float = 0.0) -> bool:
	return absf(attacker.elevation - target.elevation) <= VERTICAL_REACH + extra


## Knockback multiplier: a flier aloft is easily driven off course.
static func push_factor(fighter: CombatantState) -> float:
	return 1.4 if fighter.elevation > 0.5 else 1.0


## Terrain the build would rather fight on: "water", "land" or "".
static func preferred_terrain(spec: CombatantSpec) -> String:
	match spec.movement_type:
		M.SWIMMING, M.AMPHIBIOUS:
			return "water"
		M.GROUND:
			return "land"
	return ""
