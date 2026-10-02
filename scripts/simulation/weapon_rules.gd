class_name WeaponRules
extends RefCounted
## How weapons and advanced techniques change a fight, read from data so a
## new weapon or technique needs no engine code.
##
## Weapon traits (WeaponData, "Behavior"):
## - heavy_hyper_armor — heavy wind-ups and strikes are not flinched by
##   light blows (Hammer, Axe).
## - flank_bonus — extra damage from a target's side or back (Dagger).
## - block_bonus — a stronger, cheaper guard (Shield).
## - point_blank_factor — shots at close range hit weakly (Bow).
##
## Techniques (TechniqueData triggers), used only when learned:
## - AFTER_BLOCK_ATTACK (Riposte): the first light cut within a moment of a
##   successful guard or parry strikes with the technique's power.
## - HEAVY_VS_GUARD (Guard Break): a heavy blow that is blocked breaks the
##   guard outright.
## - HEAVY_WITH_MAGIC (Flame Slash): a heavy blow with the required school
##   attuned strikes harder and sets the target burning.
## - MAGIC_DODGE (Wind Dash): with the required school attuned, dodges
##   carry further.

const A := CombatantState.Action
const P := CombatantState.Phase
const T := TechniqueData.Trigger

## Seconds after a successful guard in which a riposte can follow.
const RIPOSTE_WINDOW := 0.75
## Half-angle (degrees) of a target's front; outside it a blow is a flank.
const FRONT_HALF_ANGLE := 60.0
const FLAME_SLASH_BURN := {"kind": "burn", "dps": 4.0, "time": 2.5}


## The learned technique of `trigger` this combatant can use right now, or null.
static func technique(fighter: CombatantState, trigger: TechniqueData.Trigger) -> TechniqueData:
	for technique_id in fighter.spec.techniques:
		var data := Content.technique(technique_id)
		if data == null or data.trigger != trigger:
			continue
		if not data.required_school.is_empty() and \
				(fighter.spec.ability == null or fighter.spec.ability.school != data.required_school):
			continue
		return data
	return null


## Tags a hit with the technique it carries and whether it is a flank.
static func shape_hit(state: BattleState, attacker: CombatantState, target: CombatantState, hit: Dictionary) -> void:
	hit["technique"] = ""
	if hit["kind"] == "light" and int(hit.get("combo", 1)) == 1 \
			and state.time - attacker.last_guard_time <= RIPOSTE_WINDOW:
		var riposte := technique(attacker, T.AFTER_BLOCK_ATTACK)
		if riposte != null:
			hit["technique"] = riposte.id
	elif hit["kind"] == "heavy":
		var slash := technique(attacker, T.HEAVY_WITH_MAGIC)
		if slash != null:
			hit["technique"] = slash.id
	var offset := attacker.position - target.position
	hit["flank"] = offset.length() > 0.001 and \
			rad_to_deg(absf(target.facing.angle_to(offset))) > FRONT_HALF_ANGLE


## Damage multiplier from weapon traits and techniques.
static func damage_factor(state: BattleState, attacker: CombatantState, target: CombatantState, hit: Dictionary) -> float:
	var factor := 1.0
	var weapon := attacker.spec.weapon
	if hit["kind"] != "cast" and weapon != null:
		if hit.get("flank", false):
			factor *= 1.0 + weapon.flank_bonus
		if hit.get("via", "") == "projectile" and \
				attacker.position.distance_to(target.position) < weapon.point_blank_range:
			factor *= weapon.point_blank_factor
	var used := Content.technique(hit.get("technique", ""))
	if used != null:
		factor *= used.power
	return factor


## Share of damage a guard lets through and of stamina it pays, with the
## held weapon's guard bonus.
static func guard_factor(defender: CombatantState) -> float:
	var weapon := defender.spec.weapon
	return 1.0 - (weapon.block_bonus if weapon != null else 0.0)


## True while heavy-weapon hyper armor holds against a light blow.
static func has_hyper_armor(fighter: CombatantState) -> bool:
	var weapon := fighter.spec.weapon
	return weapon != null and weapon.heavy_hyper_armor and fighter.action == A.HEAVY \
			and (fighter.phase == P.WINDUP or fighter.phase == P.ACTIVE)


## Dodge distance multiplier from a MAGIC_DODGE technique.
static func dodge_factor(fighter: CombatantState) -> float:
	var dash := technique(fighter, T.MAGIC_DODGE)
	return dash.power if dash != null else 1.0
