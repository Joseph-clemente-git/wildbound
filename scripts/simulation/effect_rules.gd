class_name EffectRules
extends RefCounted
## Lasting effects on a combatant, kept in CombatantState.effects as plain
## dictionaries so they replay and save cleanly:
##
## - burn  {"dps", "time", "source", "tick"} — damage over time from Fire;
##         armor only blunts half of it. Applied every quarter second.
## - slow  {"factor", "time", "source"} — movement slowed (Frost, Nature).
## - ward  {"factor", "time"} — a share of incoming damage turned aside
##         (Earth). The caster wards itself.
##
## A new effect of a kind replaces the old one if it is stronger or lasts
## longer, so effects never stack into something unanswerable. Timers run
## out in the Cooldown / Recovery step.

const BURN_TICK := 0.25


static func apply(target: CombatantState, effect: Dictionary) -> void:
	for existing in target.effects:
		if existing.get("kind", "") == effect["kind"]:
			for key: String in effect:
				if key == "time" or key == "dps" or key == "factor":
					existing[key] = maxf(float(existing.get(key, 0.0)), float(effect[key]))
				else:
					existing[key] = effect[key]
			return
	target.effects.append(effect.duplicate())


static func burn(target: CombatantState, dps: float, seconds: float, source: int) -> void:
	if dps > 0.0 and seconds > 0.0:
		apply(target, {"kind": "burn", "dps": dps, "time": seconds, "source": source, "tick": 0.0})


## Applies what an Art leaves behind on whoever it struck cleanly.
static func on_art_hit(ability: MagicAbilityData, caster: CombatantState, target: CombatantState) -> void:
	burn(target, ability.burn_dps, ability.burn_seconds, caster.index)
	if ability.slow_factor > 0.0 and ability.slow_seconds > 0.0:
		apply(target, {"kind": "slow", "factor": ability.slow_factor, "time": ability.slow_seconds, "source": caster.index})


## Applies what an Art does for its caster on release.
static func on_release(ability: MagicAbilityData, caster: CombatantState) -> void:
	if ability.ward_factor > 0.0 and ability.ward_seconds > 0.0:
		apply(caster, {"kind": "ward", "factor": ability.ward_factor, "time": ability.ward_seconds})


static func strength(fighter: CombatantState, kind: String) -> float:
	for effect in fighter.effects:
		if effect.get("kind", "") == kind:
			return float(effect.get("factor", 0.0))
	return 0.0


## Movement multiplier from slows.
static func speed_factor(fighter: CombatantState) -> float:
	return 1.0 - clampf(strength(fighter, "slow"), 0.0, 0.8)


## Damage multiplier from wards.
static func ward_factor(fighter: CombatantState) -> float:
	return 1.0 - clampf(strength(fighter, "ward"), 0.0, 0.8)


## Burn damage due this tick, applied in quarter-second pulses.
static func tick_burns(state: BattleState, frame: SimFrame) -> void:
	for fighter in state.combatants:
		if not fighter.is_alive():
			continue
		for effect in fighter.effects:
			if effect.get("kind", "") != "burn":
				continue
			effect["tick"] = float(effect.get("tick", 0.0)) + frame.delta
			if float(effect["tick"]) < BURN_TICK:
				continue
			effect["tick"] = float(effect["tick"]) - BURN_TICK
			var amount := float(effect["dps"]) * BURN_TICK * (1.0 - fighter.spec.derived.mitigation * 0.5) * ward_factor(fighter)
			fighter.health = maxf(fighter.health - amount, 0.0)
			frame.emit("damage", int(effect.get("source", -1)), fighter.index, {"amount": snappedf(amount, 0.01),
					"kind": "burn", "outcome": "hit", "opening": false, "health_left": snappedf(fighter.health, 0.01)})
