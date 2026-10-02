class_name ForcePhase
extends SimulationPhase
## Stagger / Knockback: the physical force of blows.
##
## - Every clean blow builds the target's stagger meter: weapon stagger
##   (heavy blows far more), raised by the attacker's Strength, shrunk by
##   armor and defense-control skill. Passing the target's poise (from
##   Defense) staggers it — the current action is lost — and one huge blow
##   knocks it down. A blocked blow still adds a little guard pressure.
## - Lesser clean blows flinch (a brief interruption) when they carry at
##   least a quarter of the target's poise; weaker ones are shrugged off.
## - Staggers last longer for heavier blows and shorter with recovery skill
##   and Agility. The meter drains when left alone.
## - A parry staggers the attacker; a broken guard staggers the defender.
## - Blows push: knockback from the attacker's Strength and weapon, resisted
##   by armor, positioning skill and Defense. Pushes slide out on their own,
##   apart from walking.

const A := CombatantState.Action
const P := CombatantState.Phase

## A clean blow's flinch: the target's current action is interrupted briefly.
const FLINCH_SECONDS := 0.35
## A blow flinches only if its stagger reaches this share of the target's
## poise — light cuts do not interrupt a heavily armored, high-Defense body.
const FLINCH_SHARE := 0.25
const STAGGER_SECONDS := 0.55
const KNOCKDOWN_SECONDS := 1.1
const PARRY_STAGGER_SECONDS := 0.7
const GUARD_BREAK_SECONDS := 0.9
## A single blow this many times the poise knocks down.
const KNOCKDOWN_SHARE := 1.4
## Share of stagger a guard still feels.
const GUARD_STAGGER_SHARE := 0.3
## Share of knockback a guard still feels.
const GUARD_PUSH_SHARE := 0.4
## Poise fraction recovered per second.
const METER_DRAIN := 0.3
## Push speed (m/s) per point of knockback.
const PUSH_SPEED := 2.2


func _init() -> void:
	super("force")


func run(state: BattleState, frame: SimFrame) -> void:
	for hit in frame.hits:
		var attacker := state.combatants[hit["attacker"]]
		var target := state.combatants[hit["target"]]
		match hit.get("outcome", "hit"):
			"hit":
				if target.is_alive():
					_struck(attacker, target, hit, frame, 1.0, 1.0)
			"blocked":
				if target.is_alive():
					_struck(attacker, target, hit, frame, GUARD_STAGGER_SHARE, GUARD_PUSH_SHARE)
					var used := Content.technique(hit.get("technique", ""))
					if used != null and used.trigger == TechniqueData.Trigger.HEAVY_VS_GUARD:
						frame.emit("guard_break", target.index, attacker.index, {"technique": used.id})
						stagger(target, GUARD_BREAK_SECONDS, frame, "guard_break", attacker.index)
			"parried":
				if attacker.is_alive():
					stagger(attacker, PARRY_STAGGER_SECONDS, frame, "parried", target.index)
	for fighter in state.combatants:
		if fighter.stagger_meter > 0.0:
			fighter.stagger_meter = maxf(fighter.stagger_meter - fighter.spec.derived.poise * METER_DRAIN * frame.delta, 0.0)


## The stagger a hit carries before the target's resistances.
static func stagger_of(attacker: CombatantState, hit: Dictionary) -> float:
	var derived := attacker.spec.derived
	match hit["kind"]:
		"heavy":
			return derived.heavy_stagger_power
		"cast":
			var ability := Content.ability(hit.get("ability", ""))
			return ability.stagger if ability != null else 0.0
	return derived.stagger_power


static func knockback_of(attacker: CombatantState, hit: Dictionary) -> float:
	match hit["kind"]:
		"heavy":
			return attacker.spec.derived.knockback_power
		"cast":
			var ability := Content.ability(hit.get("ability", ""))
			return ability.knockback if ability != null else 0.0
	return attacker.spec.derived.knockback_power * 0.5


## How much of a push a combatant feels: armor, positioning skill, Defense.
static func push_taken(fighter: CombatantState) -> float:
	return fighter.spec.derived.knockback_taken * clampf(1.0 - fighter.spec.get_stat("defense") / 400.0, 0.6, 1.0)


## Seconds a stagger lasts for this combatant: recovery skill and Agility
## shorten it.
static func stagger_seconds(fighter: CombatantState, base: float) -> float:
	var agility := clampf(1.1 - fighter.spec.get_stat("agility") / 250.0, 0.7, 1.1)
	return base * (fighter.spec.derived.hit_recovery / 0.35) * agility


static func stagger(fighter: CombatantState, base_seconds: float, frame: SimFrame, reason: String,
		by: int, action: CombatantState.Action = CombatantState.Action.STAGGER, keep_meter: bool = false) -> void:
	var seconds := stagger_seconds(fighter, base_seconds)
	if fighter.action in [A.ATTACK, A.HEAVY, A.CAST] and fighter.phase == P.WINDUP:
		frame.emit("interrupted", fighter.index, by, {"action": CombatantState.ACTION_NAMES[fighter.action]})
	fighter.action = action
	fighter.phase = P.RECOVERY
	fighter.phase_time = 0.0
	fighter.phase_length = seconds
	fighter.combo_step = 0
	if not keep_meter:
		fighter.stagger_meter = 0.0
	fighter.velocity = Vector2.ZERO
	if fighter.spec.movement_type == GameEnums.MovementType.FLYING and action != A.FLINCH:
		fighter.grounded_time = maxf(fighter.grounded_time, TerrainRules.GROUNDED_SECONDS)  # knocked out of the air
	frame.emit("knockdown" if action == A.KNOCKDOWN else ("flinch" if reason == "flinch" else "staggered"), fighter.index, by,
			{"reason": reason, "seconds": snappedf(seconds, 0.001)})


func _struck(attacker: CombatantState, target: CombatantState, hit: Dictionary, frame: SimFrame,
		stagger_share: float, push_share: float) -> void:
	var build := stagger_of(attacker, hit) * target.spec.derived.stagger_taken * stagger_share \
			* float(hit.get("stagger_scale", 1.0))
	target.stagger_meter += build
	hit["stagger"] = build
	var poise := target.spec.derived.poise
	if stagger_share >= 1.0 and build >= poise * KNOCKDOWN_SHARE:
		stagger(target, KNOCKDOWN_SECONDS, frame, "knockdown", attacker.index, A.KNOCKDOWN)
	elif target.stagger_meter >= poise:
		stagger(target, STAGGER_SECONDS * (1.3 if hit["kind"] == "heavy" else 1.0), frame, hit["kind"], attacker.index)
	elif stagger_share >= 1.0 and target.action not in [A.STAGGER, A.KNOCKDOWN, A.RECOVER] and build >= poise * FLINCH_SHARE:
		# A clean blow flinches — unless a heavy weapon's committed swing shrugs off a lighter one.
		if WeaponRules.has_hyper_armor(target) and hit["kind"] != "heavy":
			frame.emit("armored", target.index, attacker.index)
		elif target.action == A.CAST and target.spec.ability != null and not target.spec.ability.interruptible:
			frame.emit("armored", target.index, attacker.index)
		else:
			stagger(target, FLINCH_SECONDS, frame, "flinch", attacker.index, A.FLINCH, true)
	var ability := Content.ability(hit.get("ability", "")) if hit["kind"] == "cast" else null
	if ability != null and ability.grounds_fliers and target.elevation > 0.5 and stagger_share >= 1.0 \
			and target.action != A.KNOCKDOWN:
		stagger(target, KNOCKDOWN_SECONDS * 0.6, frame, "grounded", attacker.index, A.KNOCKDOWN)
	var push := knockback_of(attacker, hit) * push_taken(target) * push_share * TerrainRules.push_factor(target)
	if push > 0.01:
		var direction: Vector2 = hit.get("direction", Vector2.ZERO)
		target.push_velocity += direction * push * PUSH_SPEED
		frame.emit("knockback", target.index, attacker.index, {"force": snappedf(push, 0.01)})
