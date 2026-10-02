class_name DefenseRules
extends RefCounted
## How a hit that reached its target is answered — decided at the moment of
## contact by timing and position, never by a roll:
##
## - **evaded**: the target is inside a dodge's protected window (its length
##   comes from dodge skill; Evasion sets how far and how quickly the dodge
##   moves and recovers). Inside the first half of the perfect window the
##   evade is *perfect* — the moment the decision layer looks for to counter.
## - **parried**: a guard raised moments before the blow (within the perfect
##   window, widened by Timing) facing the attacker turns a melee blow aside
##   completely; the attacker is left exposed (staggered in Stage 13).
## - **blocked**: a raised guard facing the attacker takes the blow; only the
##   guard's factor gets through (block skill and Defense) and the guard
##   pays stamina for it, scaled by the attacker's weapon guard pressure.
## - **hit**: everything else — including guards still being raised and
##   blows from behind.

const A := CombatantState.Action
const P := CombatantState.Phase

## Half-angle (degrees) a guard covers around the defender's facing.
const GUARD_HALF_ANGLE := 70.0
## Fraction of the perfect window that counts for a perfect dodge.
const PERFECT_DODGE_SHARE := 0.5
## Stamina drained from a guard per point of raw damage, before pressure.
const GUARD_DRAIN_PER_DAMAGE := 0.35


## Fills `outcome`, `perfect` and `guard_drain` on a hit.
static func resolve(attacker: CombatantState, target: CombatantState, hit: Dictionary) -> void:
	hit["outcome"] = "hit"
	hit["perfect"] = false
	hit["guard_drain"] = 0.0
	var window := target.spec.derived.perfect_window
	if target.action == A.DODGE and target.phase == P.ACTIVE:
		hit["outcome"] = "evaded"
		hit["perfect"] = target.phase_time <= window * PERFECT_DODGE_SHARE
		return
	if target.action == A.BLOCK and target.phase == P.ACTIVE and faces(target, attacker.position):
		var perfect := target.phase_time <= window
		if perfect and hit["via"] == "melee":
			hit["outcome"] = "parried"
			hit["perfect"] = true
			return
		hit["outcome"] = "blocked"
		hit["perfect"] = perfect
		hit["guard_drain"] = DamagePhase.raw_damage(attacker, hit) * GUARD_DRAIN_PER_DAMAGE \
				* attacker.spec.derived.guard_pressure * (0.5 if perfect else 1.0)


## Whether a defender's guard covers a blow coming from `source`.
static func faces(defender: CombatantState, source: Vector2) -> bool:
	var toward := source - defender.position
	if toward.length() < 0.001:
		return true
	return rad_to_deg(absf(defender.facing.angle_to(toward))) <= GUARD_HALF_ANGLE
