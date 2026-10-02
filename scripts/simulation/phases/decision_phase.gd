class_name DecisionPhase
extends SimulationPhase
## Combat Decision: each combatant's mind reads the battle and chooses an
## intent. Nothing here decides who wins — it decides what each fighter
## *tries*, and the rest of the pipeline decides what that achieves.
##
## A mind works from what it can see and what it is:
## - **Threats.** An enemy wind-up that will reach, a cast aimed its way or
##   a shot in flight is noticed after a reaction time (shorter with Timing
##   skill, Agility and battle experience). The mind then answers with a
##   dodge, a block, a counter-strike or a sidestep — chosen from its skills,
##   stats, armor, the threat and its tendencies — and times it for the
##   perfect moment, with an error that shrinks with Timing, the matching
##   skill and battle experience. A novice who dodges too early is still
##   recovering when the blow lands.
## - **Initiative.** Punish openings (heavy blows when there is time),
##   pressure exhausted or guarding enemies, keep combos going, cast an Art
##   when its shape suits the moment.
## - **Condition.** Low stamina disengages to recover; low health turns
##   defensive. Caution decides how early.
## - **Position.** Hold the build's preferred range, circle by mobility,
##   flank with agile builds, keep off the ring edge and around obstacles.
##
## The build's CombatStyle shapes all of it. The only randomness is a small,
## seeded spread on reactions, timing and how eagerly a tendency acts.

const A := CombatantState.Action
const P := CombatantState.Phase
const E := MagicAbilityData.Effect

## Ideal moment to begin a dodge: this long before the blow lands.
const DODGE_LEAD := 0.05
## A guard should finish rising this long before the blow lands.
const BLOCK_LEAD := 0.06
## How long a guard is held after the blow should have landed.
const GUARD_HOLD := 0.25
## Margin added to an enemy's reach when judging a threat.
const THREAT_MARGIN := 0.5
const EDGE_MARGIN := 1.6
## A ranged build will not shoot from closer than this; it makes room first.
const RANGED_CLOSE := 3.5
## ...and shoots unprovoked only from this far, so each shot buys distance.
const RANGED_SHOOT := 5.0


## What a combatant knows and intends, kept between ticks.
class Mind:
	var style := CombatStyle.BALANCED
	var preferred := 2.0
	var reaction := 0.3
	var precision := 0.1
	var strafe := 1.0
	var strafe_until := 0.0
	var threat_key := ""
	var noticed_at := INF
	var replanned := false
	var response := ""
	var respond_at := INF
	var give_up_at := INF
	var dodge_dir := Vector2.ZERO
	var guard_until := -1.0


var minds: Dictionary = {}


func _init() -> void:
	super("decision")


func run(state: BattleState, frame: SimFrame) -> void:
	for fighter in state.combatants:
		if not fighter.is_alive():
			continue
		_retarget(state, fighter)
		if state.target_of(fighter) == null:
			continue
		frame.intents[fighter.index] = decide(state, fighter, mind_of(state, fighter), frame)


func mind_of(state: BattleState, fighter: CombatantState) -> Mind:
	if minds.has(fighter.index):
		return minds[fighter.index]
	var mind := Mind.new()
	var spec := fighter.spec
	mind.style = CombatStyle.of(spec)
	mind.preferred = spec.tendency("preferred_range") if spec.source == "opponent" else CombatStyle.preferred_range(spec)
	mind.reaction = reaction_time(spec)
	mind.precision = timing_error(spec)
	mind.strafe = 1.0 if state.rng.randf() < 0.5 else -1.0
	minds[fighter.index] = mind
	return mind


## Seconds to notice a threat: Timing skill, Agility and lived experience.
static func reaction_time(spec: CombatantSpec) -> float:
	var experience := minf(spec.battle_experience, 80.0)
	return clampf(0.3 - spec.rank_of("skill:timing") * 0.03 - spec.get_stat("agility") * 0.001 - experience * 0.0015,
			0.08, 0.4)


## Half-width of the timing error on a defensive answer.
static func timing_error(spec: CombatantSpec) -> float:
	var experience := minf(spec.battle_experience, 80.0)
	return maxf(0.2 - spec.rank_of("skill:timing") * 0.022 - experience * 0.0012, 0.03)


# --- Decision ---------------------------------------------------------------------

func decide(state: BattleState, me: CombatantState, mind: Mind, frame: SimFrame) -> Dictionary:
	var target := state.target_of(me)
	var intent := {"move": _movement(state, me, target, mind, frame)}
	var answer := _answer_threats(state, me, mind, frame)
	if answer.get("hold", false):
		return intent  # a blow it has seen coming: no new attack into it
	if not answer.is_empty():
		intent.merge(answer, true)
		return intent
	var act := _initiative(state, me, target, mind, frame)
	if not act.is_empty():
		intent.merge(act, true)
	return intent


# --- Threats ----------------------------------------------------------------------

## The soonest danger coming at `me`: {"key", "time", "kind", "source",
## "heavy", "armored", "direction"} or {}.
static func threat_to(state: BattleState, me: CombatantState) -> Dictionary:
	var best := {}
	for enemy in state.enemies_of(me):
		if not enemy.is_alive():
			continue
		var found := _threat_from(enemy, me)
		if not found.is_empty() and (best.is_empty() or found["time"] < best["time"]):
			best = found
	for shot in state.projectiles:
		if shot["team"] == me.team:
			continue
		var relative: Vector2 = me.position - shot["position"]
		var along := relative.dot(shot["direction"])
		if along <= 0.0 or along > float(shot["range_left"]) + CombatantState.BODY_RADIUS:
			continue
		var lateral: float = (relative - shot["direction"] * along).length()
		if lateral > CombatantState.BODY_RADIUS + float(shot["radius"]) + 0.15:
			continue
		var time := along / float(shot["speed"])
		if best.is_empty() or time < best["time"]:
			best = {"key": "p%d" % shot["id"], "time": time, "kind": "projectile", "source": shot["owner"],
					"heavy": false, "armored": false, "direction": shot["direction"]}
	return best


static func _threat_from(enemy: CombatantState, me: CombatantState) -> Dictionary:
	if enemy.phase != P.WINDUP:
		return {}
	var offset := me.position - enemy.position
	var distance := offset.length()
	var facing_me := distance < 0.01 or rad_to_deg(absf(enemy.facing.angle_to(offset))) <= 40.0
	var remaining := maxf(enemy.phase_length - enemy.phase_time, 0.0)
	var key := "%d:%d" % [enemy.index, enemy.swing]
	var base := {"key": key, "source": enemy.index, "direction": offset.normalized() if distance > 0.01 else enemy.facing}
	match enemy.action:
		A.ATTACK, A.HEAVY:
			var weapon := enemy.spec.weapon
			var heavy := enemy.action == A.HEAVY
			base.merge({"heavy": heavy, "armored": WeaponRules.has_hyper_armor(enemy)}, true)
			if weapon != null and weapon.projectile_speed > 0.0:
				if facing_me and distance <= weapon.attack_range:
					base.merge({"time": remaining + distance / weapon.projectile_speed, "kind": "projectile"}, true)
					return base
				return {}
			var derived := enemy.spec.derived
			var in_arc := distance < 0.01 or rad_to_deg(absf(enemy.facing.angle_to(offset))) <= derived.arc_degrees * 0.5 + 25.0
			if distance - CombatantState.BODY_RADIUS <= derived.attack_range + THREAT_MARGIN and in_arc:
				base.merge({"time": remaining, "kind": "heavy" if heavy else "melee"}, true)
				return base
		A.CAST:
			var ability := enemy.spec.ability
			if ability == null:
				return {}
			base.merge({"heavy": false, "armored": false}, true)
			match ability.effect:
				E.PROJECTILE:
					if facing_me and distance <= ability.cast_range:
						base.merge({"time": remaining + distance / maxf(ability.speed, 0.1), "kind": "projectile"}, true)
						return base
				E.CONE_PUSH:
					if facing_me and distance <= ability.cast_range + CombatantState.BODY_RADIUS + THREAT_MARGIN:
						base.merge({"time": remaining, "kind": "area"}, true)
						return base
				E.NOVA:
					if distance <= ability.radius + CombatantState.BODY_RADIUS + THREAT_MARGIN:
						base.merge({"time": remaining, "kind": "area"}, true)
						return base
	return {}


func _answer_threats(state: BattleState, me: CombatantState, mind: Mind, frame: SimFrame) -> Dictionary:
	var threat := threat_to(state, me)
	if threat.is_empty():
		mind.threat_key = ""
		mind.response = ""
		mind.noticed_at = INF
		if me.action == A.BLOCK and state.time < mind.guard_until:
			return {"action": "block"}
		return {}
	if threat["key"] != mind.threat_key:
		_plan_answer(state, me, mind, threat, INF)
	elif mind.response.is_empty() and not mind.replanned and state.time >= mind.noticed_at \
			and (ActionPhase.is_free(me) or (me.action == A.ATTACK and me.phase == P.RECOVERY)):
		# Seen while committed; free again before it lands — answer it now.
		mind.replanned = true
		_plan_answer(state, me, mind, threat, state.time)
	var seen := state.time >= mind.noticed_at
	if mind.response.is_empty() or state.time > mind.give_up_at:
		# Seen but unanswerable: at least do not swing into it.
		return {"hold": true} if seen and state.time <= mind.give_up_at else {}
	if state.time + frame.delta * 0.5 < mind.respond_at:
		# Seen it coming: keep the guard up or hold back while waiting.
		if me.action == A.BLOCK:
			return {"action": "block"}
		return {"hold": true} if seen else {}
	match mind.response:
		"dodge":
			mind.response = ""
			return {"action": "dodge", "dodge_dir": mind.dodge_dir}
		"block":
			mind.guard_until = maxf(mind.guard_until, state.time + float(threat["time"]) + GUARD_HOLD)
			return {"action": "block"}
		"counter":
			mind.response = ""
			return {"action": "attack"}
		"sidestep":
			return {"move": mind.dodge_dir}
	return {}


## Chooses and times the answer to a threat — when first seen, or again
## when the combatant frees up (`seen_at`) before it lands.
func _plan_answer(state: BattleState, me: CombatantState, mind: Mind, threat: Dictionary, seen_at: float) -> void:
	if seen_at == INF:
		mind.threat_key = threat["key"]
		mind.replanned = false
		mind.noticed_at = state.time + mind.reaction * (1.0 + state.rng.randf_range(-0.15, 0.15))
	mind.response = ""
	var noticed := maxf(mind.noticed_at, state.time)
	var strike := state.time + float(threat["time"])
	mind.give_up_at = strike + GUARD_HOLD
	if noticed >= strike - 0.02:
		return  # too fast to read: it lands
	var spec := me.spec
	var derived := spec.derived
	var free := ActionPhase.is_free(me) or (me.action == A.ATTACK and me.phase == P.RECOVERY)
	if me.is_exhausted() or not free:
		return
	var direction: Vector2 = threat["direction"]
	var side := Vector2(-direction.y, direction.x)
	if (me.position + side).length() > (me.position - side).length():
		side = -side  # sidestep toward the open ring
	var reach := spec.derived.dodge_distance
	if TerrainRules.preferred_terrain(spec) == "land" and state.layout.in_water(me.position + side * reach) \
			and not state.layout.in_water(me.position - side * reach):
		side = -side  # and away from deep water
	var scores := {}
	var stamina := me.stamina
	if stamina >= derived.dodge_stamina * 0.8:
		scores["dodge"] = 0.35 + spec.rank_of("skill:dodge") * 0.08 + spec.get_stat("evasion") / 200.0 \
				+ spec.tendency("mobility") * 0.3 + (0.35 if threat["heavy"] else 0.0) \
				+ (0.2 if threat["kind"] == "projectile" or threat["kind"] == "area" else 0.0) \
				- (0.3 if spec.armor != null and spec.armor.weight_class == GameEnums.ArmorWeight.HEAVY else 0.0) \
				+ (0.3 if mind.style == CombatStyle.AGILE or mind.style == CombatStyle.RANGED else 0.0)
	if stamina > 8.0 and threat["kind"] != "area":
		var shield := spec.weapon.block_bonus if spec.weapon != null else 0.0
		scores["block"] = 0.35 + spec.rank_of("skill:block") * 0.08 + spec.get_stat("defense") / 200.0 + shield * 0.8 \
				+ (0.2 if threat["kind"] == "melee" else 0.0) - (0.35 if threat["heavy"] else 0.0) \
				- (0.3 if stamina < me.max_stamina * 0.3 else 0.0)
	if threat["kind"] == "melee" or threat["kind"] == "heavy":
		var attacker := state.combatants[threat["source"]]
		var mine := derived.windup + 0.04
		if not threat["armored"] and mine < strike - noticed and stamina >= derived.attack_stamina \
				and ContactPhase.in_reach(state, me, attacker, derived.attack_range, derived.arc_degrees + 40.0):
			scores["counter"] = 0.2 + spec.tendency("aggression") * 0.6 + spec.rank_of("skill:timing") * 0.05
	if threat["kind"] == "projectile" and float(threat["time"]) > 0.55:
		scores["sidestep"] = 0.55 + spec.tendency("mobility") * 0.3
	if scores.is_empty():
		return
	var best := ""
	var best_score := -INF
	for option: String in scores:
		var score: float = scores[option] + state.rng.randf_range(-0.1, 0.1)
		if score > best_score:
			best_score = score
			best = option
	mind.response = best
	var error_for := func(skill: String) -> float:
		var width := maxf(mind.precision - spec.rank_of(skill) * 0.012, 0.02)
		return state.rng.randf_range(-width, width)
	match best:
		"dodge":
			mind.dodge_dir = (side + (-direction if threat["heavy"] else Vector2.ZERO) * 0.5).normalized()
			mind.respond_at = maxf(noticed, strike - DODGE_LEAD - absf(error_for.call("skill:dodge")) * 0.5 + error_for.call("skill:dodge"))
		"block":
			mind.respond_at = maxf(noticed, strike - Content.config.simulation_block_raise_seconds - BLOCK_LEAD
					+ error_for.call("skill:block"))
			mind.guard_until = strike + GUARD_HOLD
		"counter":
			mind.respond_at = noticed
		"sidestep":
			mind.dodge_dir = side
			mind.respond_at = noticed


# --- Initiative ---------------------------------------------------------------------

func _initiative(state: BattleState, me: CombatantState, target: CombatantState, mind: Mind, frame: SimFrame) -> Dictionary:
	var spec := me.spec
	var derived := spec.derived
	var distance := me.position.distance_to(target.position)
	var caution := spec.tendency("caution")
	var aggression := spec.tendency("aggression") * (0.6 if me.health_ratio() < 0.3 else 1.0)
	var open := DamagePhase.is_open(target) or target.is_exhausted()
	var in_reach := can_reach(state, me, target)
	# Keep a chain going while it is working.
	if me.action == A.ATTACK and me.phase == P.RECOVERY and me.combo_step < derived.combo_max \
			and mind.style != CombatStyle.HEAVY:
		if in_reach and target.action != A.BLOCK and me.stamina > derived.attack_stamina \
				and (open or _chance(state, 3.0 + aggression * 6.0, frame.delta)):
			return {"action": "attack"}
		return {}
	if not ActionPhase.is_free(me) or me.is_exhausted():
		return {}
	# Keep a guard up while an anticipated exchange plays out; strike out of it
	# the moment the enemy opens up.
	if me.action == A.BLOCK and state.time < mind.guard_until:
		if open and in_reach:
			mind.guard_until = state.time
			return {"action": _punish_with(me, target)}
		return {"action": "block"}
	var tired := me.stamina_ratio() < 0.15 + caution * 0.2
	if tired and not open:
		return {}  # the movement plan backs off to recover
	var magic := _magic(state, me, target, mind, distance, open, frame)
	if not magic.is_empty():
		return magic
	if not in_reach:
		return {}
	var heavy_cost := derived.heavy_stamina
	if mind.style == CombatStyle.RANGED and (distance < RANGED_CLOSE or (distance < RANGED_SHOOT and not open)):
		return {}  # too close to shoot well: get distance first
	if open:
		return {"action": _punish_with(me, target)}
	if mind.style == CombatStyle.AGILE and not _flanking(me, target) and me.stamina_ratio() < 0.8:
		return {}  # circle for the flank instead of trading head-on
	if target.action == A.BLOCK:
		var pressure := spec.tendency("heavy_chance") + (0.35 if derived.guard_pressure > 1.5 else 0.0)
		if me.stamina > heavy_cost and _chance(state, 1.5 * pressure, frame.delta):
			return {"action": "heavy"}
		return {}
	# Anticipate: an enemy in striking distance may swing faster than anyone
	# can react, so careful fighters raise a guard ahead of it.
	if ActionPhase.is_free(target) and _enemy_reaches(state, target, me) and me.stamina_ratio() > 0.35:
		var wary := caution * 1.2 + spec.rank_of("skill:block") * 0.15 + (0.6 if me.health_ratio() < 0.4 else 0.0)
		if mind.style == CombatStyle.HEAVY:
			wary *= 0.5
		elif mind.style == CombatStyle.RANGED or mind.style == CombatStyle.AGILE:
			wary *= 0.3  # these builds would rather not be there at all
		if _chance(state, wary, frame.delta):
			mind.guard_until = state.time + state.rng.randf_range(0.5, 1.1)
			return {"action": "block"}
	# Swinging into a ready opponent risks a dodge, a parry or a counter, so
	# unprovoked attacks come at a pace set by aggression; openings are taken
	# at once (above).
	var rate := 1.1 * aggression
	if mind.style == CombatStyle.HEAVY:
		rate *= 0.8
	if is_flagging(target):
		rate *= 2.5  # a tired opponent is pressed hard
	if not _chance(state, rate, frame.delta):
		return {}
	var heavy_wish := spec.tendency("heavy_chance") + (0.2 if target.stagger_meter > target.spec.derived.poise * 0.5 else 0.0)
	if mind.style == CombatStyle.HEAVY:
		heavy_wish = maxf(heavy_wish, 0.6)
	if me.stamina > heavy_cost * 1.2 and state.rng.randf() < heavy_wish:
		return {"action": "heavy"}
	return {"action": "attack"}


## The blow that punishes an opening: a heavy when it lands in time.
## Hyper armor lets a heavy weapon throw its heavy into a shorter window.
static func _punish_with(me: CombatantState, target: CombatantState) -> String:
	var derived := me.spec.derived
	var window := maxf(target.phase_length - target.phase_time, 0.0) if target.phase != P.NONE else 0.4
	var armored := me.spec.weapon != null and me.spec.weapon.heavy_hyper_armor
	var needed := derived.heavy_windup * (0.5 if armored else 1.0)
	return "heavy" if needed + 0.05 < window and me.stamina > derived.heavy_stamina else "attack"


func _magic(state: BattleState, me: CombatantState, target: CombatantState, mind: Mind, distance: float,
		open: bool, frame: SimFrame) -> Dictionary:
	var ability := me.spec.ability
	if ability == null or me.cooldown("magic") > 0.0 or me.stamina < ability.stamina_cost * 1.2:
		return {}
	var eager := me.spec.tendency("magic_chance")
	if eager <= 0.0:
		return {}
	var pressed := distance < mind.preferred * 0.8 or me.health_ratio() < 0.4
	match ability.effect:
		E.PROJECTILE:
			if distance > 3.0 and distance < ability.cast_range * 0.9 \
					and ContactPhase.line_clear(state, me.position, target.position):
				var rate := eager * (4.0 if open or target.is_exhausted() else 1.5)
				if mind.style == CombatStyle.RANGED:
					rate *= 1.5
				if _chance(state, rate, frame.delta):
					return {"action": "cast"}
		E.CONE_PUSH:
			if distance <= ability.cast_range and ContactPhase.in_reach(state, me, target, ability.cast_range, ability.cone_degrees) \
					and (pressed or target.phase == P.WINDUP) and _chance(state, eager * 4.0, frame.delta):
				return {"action": "cast"}
		E.NOVA:
			if distance <= ability.radius + CombatantState.BODY_RADIUS and (pressed or open) \
					and _chance(state, eager * 4.0, frame.delta):
				return {"action": "cast"}
		E.DASH:
			var cornered := me.position.length() > state.layout.radius - EDGE_MARGIN
			if (cornered or (mind.style == CombatStyle.RANGED and distance < 3.0)) and _chance(state, eager * 5.0, frame.delta):
				return {"action": "cast", "dodge_dir": (-me.position).normalized() if cornered else (me.position - target.position).normalized()}
	return {}


# --- Position -------------------------------------------------------------------

func _movement(state: BattleState, me: CombatantState, target: CombatantState, mind: Mind, frame: SimFrame) -> Vector2:
	var offset := target.position - me.position
	var distance := offset.length()
	var toward := offset / distance if distance > 0.01 else me.facing
	var spec := me.spec
	var caution := spec.tendency("caution")
	var mobility := spec.tendency("mobility")
	var wanted := mind.preferred
	var tired := me.stamina_ratio() < 0.15 + caution * 0.2 or me.is_exhausted()
	var hurt := me.health_ratio() < 0.3
	if tired:
		wanted = maxf(wanted, 4.5 + caution * 2.0)  # back off and breathe
	elif hurt and caution > 0.4:
		wanted += 1.0
	elif DamagePhase.is_open(target) or target.is_exhausted() or is_flagging(target):
		wanted = minf(wanted, spec.derived.attack_range * 0.7 + CombatantState.BODY_RADIUS)  # step in to punish or press
	var radial := 0.0
	if distance > wanted + 0.3:
		radial = 1.0
	elif distance < wanted - 0.4:
		radial = -1.0
	if state.time >= mind.strafe_until:
		mind.strafe_until = state.time + state.rng.randf_range(1.2, 3.0) * (1.4 - mobility)
		if state.rng.randf() < 0.35 + mobility * 0.3:
			mind.strafe = -mind.strafe
	var circling := (0.25 + mobility * 0.75) if distance < wanted + 1.5 else 0.2
	if mind.style == CombatStyle.AGILE and target.action in [A.ATTACK, A.HEAVY, A.CAST] \
			and target.phase != P.RECOVERY and distance < wanted + 1.0:
		# The target cannot turn while it swings: slip round to its flank,
		# then step in to punish the recovery.
		circling = 1.2
		radial = 0.0 if distance > CombatantState.BODY_RADIUS * 2.5 else -0.3
	if mind.style == CombatStyle.RANGED and distance < RANGED_SHOOT:
		radial = -1.0
		circling = maxf(circling, 0.7)  # back away on a curve, not into the wall
	var tangent := Vector2(-toward.y, toward.x) * mind.strafe * circling
	var move := toward * radial + tangent
	if me.position.length() > state.layout.radius - EDGE_MARGIN:
		move += -me.position.normalized() * 1.2
		if tangent.dot(me.position) > 0.0:
			mind.strafe = -mind.strafe
	if not ContactPhase.line_clear(state, me.position, target.position) and me.elevation < 1.5:
		move += Vector2(-toward.y, toward.x) * mind.strafe
	move += _terrain_pull(state, me)
	move = _hold_shore(state, me, move)
	return move.limit_length(1.0)


## A walker on dry land does not wade in after a swimmer: steps that would
## enter deep water slide along the shore instead. The swimmer has to come
## to the shallows to fight.
static func _hold_shore(state: BattleState, me: CombatantState, move: Vector2) -> Vector2:
	if state.layout.water_zones.is_empty() or me.elevation > 0.5 or TerrainRules.preferred_terrain(me.spec) != "land":
		return move
	if state.layout.in_water(me.position) or move.length() < 0.01:
		return move
	var ahead := me.position + move.normalized() * 0.6
	if not state.layout.in_water(ahead):
		return move
	var inward := (state.layout.nearest_water(me.position) - me.position).normalized()
	var along := move - inward * maxf(move.dot(inward), 0.0)
	return along


## Swimmers drift toward water, walkers out of it — a gentle pull that
## shapes where a fight happens without overriding it.
static func _terrain_pull(state: BattleState, me: CombatantState) -> Vector2:
	if state.layout.water_zones.is_empty() or me.elevation > 0.5:
		return Vector2.ZERO
	var water := state.layout.nearest_water(me.position)
	var toward_water := water - me.position
	if toward_water.length() < 0.01:
		return Vector2.ZERO
	match TerrainRules.preferred_terrain(me.spec):
		"water":
			if not state.layout.in_water(me.position):
				return toward_water.normalized() * 0.6
		"land":
			if state.layout.in_water(me.position):
				return -toward_water.normalized() * 0.7
	return Vector2.ZERO


func _retarget(state: BattleState, fighter: CombatantState) -> void:
	var current := state.target_of(fighter)
	if current == null or not current.is_alive():
		var nearest := state.nearest_enemy(fighter)
		fighter.target_index = nearest.index if nearest != null else -1


## Whether `me` could land a melee blow on `target` by attacking now. A
## flier that can fly dives into its swoop during the wind-up, so its own
## height does not stop it; a target high in the air is out of reach.
static func can_reach(state: BattleState, me: CombatantState, target: CombatantState) -> bool:
	var derived := me.spec.derived
	var diver := TerrainRules.can_fly(state, me)
	if not diver and not TerrainRules.vertical_reach(me, target):
		return false
	return ContactPhase.in_reach(state, me, target, derived.attack_range, derived.arc_degrees, -1.0)


static func _enemy_reaches(state: BattleState, enemy: CombatantState, me: CombatantState) -> bool:
	var derived := enemy.spec.derived
	return enemy.position.distance_to(me.position) - CombatantState.BODY_RADIUS <= derived.attack_range + THREAT_MARGIN \
			and ContactPhase.line_clear(state, enemy.position, me.position)


## Running low on breath, or landed to recover it: time to press.
static func is_flagging(target: CombatantState) -> bool:
	return target.stamina_ratio() < 0.25 or target.resting


static func _flanking(me: CombatantState, target: CombatantState) -> bool:
	var from_target := me.position - target.position
	return from_target.length() > 0.01 and rad_to_deg(absf(target.facing.angle_to(from_target))) > 55.0


## True with probability `rate_per_second` × `delta` (as a Poisson rate).
static func _chance(state: BattleState, rate_per_second: float, delta: float) -> bool:
	return state.rng.randf() < 1.0 - exp(-maxf(rate_per_second, 0.0) * delta)
