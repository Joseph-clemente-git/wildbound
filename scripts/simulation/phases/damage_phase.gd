class_name DamagePhase
extends SimulationPhase
## Damage: how much each hit that got through actually hurts.
##
##   raw    = light: derived damage, rising 10% per step along a combo
##            heavy: derived heavy damage (Strength-scaled)
##            Art:   the Art's damage, +6% per magic mastery rank above the
##                   rank it needs
##   × opening bonus when the target was committed (winding up, recovering,
##     casting) — punishing openings; weapon or magic mastery makes it larger
##   × a small controlled variation (seeded); mastery narrows it
##   × (1 − target's mitigation from Defense, armor and defense skill)
##   × the guard's factor when the hit was blocked (Stage 11)
##   × any ward on the target (Stage 15)
## Clean Art hits leave their effects (burn, slow); burns tick here too.
##
## Attack, Strength, the weapon and mastery live in the derived numbers the
## previews read, so the battle and the tactical read never disagree.

const A := CombatantState.Action
const P := CombatantState.Phase

## Damage multiplier per light-combo step after the first.
const COMBO_STEP_BONUS := 0.1
const OPENING_BONUS := 0.12
const OPENING_BONUS_PER_RANK := 0.02
## Half-width of the damage variation at no mastery, and its floor.
const VARIATION := 0.09
const VARIATION_PER_RANK := 0.012
const VARIATION_MIN := 0.02
const MAGIC_RANK_BONUS := 0.06


func _init() -> void:
	super("damage")


func run(state: BattleState, frame: SimFrame) -> void:
	EffectRules.tick_burns(state, frame)
	for hit in frame.hits:
		var outcome: String = hit.get("outcome", "hit")
		if outcome == "evaded" or outcome == "parried":
			continue
		var attacker := state.combatants[hit["attacker"]]
		var target := state.combatants[hit["target"]]
		if not target.is_alive():
			continue
		var raw := raw_damage(attacker, hit) * WeaponRules.damage_factor(state, attacker, target, hit)
		var opening := is_open(target)
		if opening and outcome == "hit":
			raw *= 1.0 + OPENING_BONUS + OPENING_BONUS_PER_RANK * mastery(attacker, hit)
		var spread := variation(attacker, hit)
		raw *= 1.0 + state.rng.randf_range(-spread, spread)
		var dealt := raw * (1.0 - target.spec.derived.mitigation) * EffectRules.ward_factor(target)
		if outcome == "blocked":
			dealt *= target.spec.derived.block_factor * WeaponRules.guard_factor(target)
		elif _burns(hit):
			var slash := WeaponRules.FLAME_SLASH_BURN
			EffectRules.burn(target, slash["dps"], slash["time"], attacker.index)
		elif hit["kind"] == "cast":
			var ability := Content.ability(hit.get("ability", ""))
			if ability != null:
				EffectRules.on_art_hit(ability, attacker, target)
		dealt = maxf(dealt, 0.0)
		target.health = maxf(target.health - dealt, 0.0)
		hit["damage"] = dealt
		hit["opening"] = opening
		frame.emit("damage", attacker.index, target.index, {"amount": snappedf(dealt, 0.01), "kind": hit["kind"],
				"outcome": outcome, "opening": opening, "health_left": snappedf(target.health, 0.01)})


static func _burns(hit: Dictionary) -> bool:
	var used := Content.technique(hit.get("technique", ""))
	return used != null and used.trigger == TechniqueData.Trigger.HEAVY_WITH_MAGIC


## Damage before the target's defences.
static func raw_damage(attacker: CombatantState, hit: Dictionary) -> float:
	var derived := attacker.spec.derived
	match hit["kind"]:
		"heavy":
			return derived.heavy_damage
		"cast":
			var ability := Content.ability(hit.get("ability", ""))
			if ability == null:
				return 0.0
			return ability.damage * (1.0 + maxi(attacker.spec.magic_mastery - ability.required_rank, 0) * MAGIC_RANK_BONUS)
	return derived.damage * (1.0 + maxi(int(hit.get("combo", 1)) - 1, 0) * COMBO_STEP_BONUS)


## Committed to something the target cannot abandon: the moment to punish.
static func is_open(target: CombatantState) -> bool:
	match target.action:
		A.ATTACK, A.HEAVY:
			return target.phase == P.WINDUP or target.phase == P.RECOVERY
		A.CAST:
			return true
		A.DODGE:
			return target.phase == P.RECOVERY
	return target.action in ActionPhase.HELD_STATES


## The skill behind this hit: weapon mastery, or magic mastery for Arts.
static func mastery(attacker: CombatantState, hit: Dictionary) -> int:
	return attacker.spec.magic_mastery if hit["kind"] == "cast" else attacker.spec.weapon_mastery


static func variation(attacker: CombatantState, hit: Dictionary) -> float:
	return maxf(VARIATION - VARIATION_PER_RANK * mastery(attacker, hit), VARIATION_MIN)
