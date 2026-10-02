class_name ContactPhase
extends SimulationPhase
## Hit / Dodge / Block, part one — attack resolution: does an attack reach
## anyone? The answer is geometry, never a roll:
##
## - Melee swings reach enemies within the weapon's reach (plus their body),
##   inside its arc around the attacker's facing, with no obstacle in the
##   way. A swing strikes each target at most once over its active window,
##   and a wide arc can catch more than one enemy.
## - Ranged weapons and projectile Arts loose a shot toward where the target
##   is at release — no leading, so moving sideways is real counterplay.
##   Shots fly at their speed, stop on obstacles and fade at their range.
## - Cone Arts strike enemies within range inside the cone; burst Arts
##   strike everyone within their radius. Movement Arts strike no one.
##
## Teammates are never struck. Everything that connects becomes a hit in
## the frame, answered on the spot by DefenseRules — evaded, parried,
## blocked or a clean hit (Stage 11) — and costed by Damage (Stage 10).
## A dodged shot flies on past its target; a blocked one stops.

const A := CombatantState.Action
const E := MagicAbilityData.Effect


func _init() -> void:
	super("contact")


func run(state: BattleState, frame: SimFrame) -> void:
	_fly(state, frame)
	for contact in frame.contacts:
		var attacker := state.combatants[contact["attacker"]]
		if not attacker.is_alive():
			continue
		match contact["kind"]:
			"light", "heavy":
				var weapon := attacker.spec.weapon
				if weapon != null and weapon.projectile_speed > 0.0:
					if contact.get("first", false):
						_loose(state, attacker, contact, frame, weapon.projectile_speed, weapon.projectile_radius,
								weapon.attack_range, "")
				else:
					_swing(state, attacker, contact, frame)
			"cast":
				_cast(state, attacker, contact, frame)


# --- Melee -----------------------------------------------------------------------

## Whether a melee swing from `attacker` reaches `target` right now.
static func in_reach(state: BattleState, attacker: CombatantState, target: CombatantState,
		reach: float, arc_degrees: float) -> bool:
	var offset := target.position - attacker.position
	var distance := offset.length()
	if distance - CombatantState.BODY_RADIUS > reach:
		return false
	if distance > 0.001:
		# The target's body widens the angle it can be struck within.
		var allowance := rad_to_deg(atan2(CombatantState.BODY_RADIUS, distance))
		if rad_to_deg(absf(attacker.facing.angle_to(offset))) > arc_degrees * 0.5 + allowance:
			return false
	return line_clear(state, attacker.position, target.position)


## True when no obstacle stands between two points.
static func line_clear(state: BattleState, from: Vector2, to: Vector2) -> bool:
	for obstacle in state.layout.obstacles:
		var centre := Vector2(obstacle.x, obstacle.y)
		if Geometry2D.get_closest_point_to_segment(centre, from, to).distance_to(centre) < obstacle.z:
			return false
	return true


func _swing(state: BattleState, attacker: CombatantState, contact: Dictionary, frame: SimFrame) -> void:
	var derived := attacker.spec.derived
	for target in state.enemies_of(attacker):
		if not target.is_alive() or attacker.struck.has(target.index):
			continue
		if in_reach(state, attacker, target, derived.attack_range, derived.arc_degrees):
			attacker.struck.append(target.index)
			_hit(attacker, target, contact, frame, "melee")


# --- Arts ------------------------------------------------------------------------

func _cast(state: BattleState, caster: CombatantState, contact: Dictionary, frame: SimFrame) -> void:
	var ability := Content.ability(contact.get("ability", ""))
	if ability == null:
		return
	match ability.effect:
		E.PROJECTILE:
			_loose(state, caster, contact, frame, ability.speed, ability.radius, ability.cast_range, ability.id)
		E.CONE_PUSH:
			for target in state.enemies_of(caster):
				if target.is_alive() and in_reach(state, caster, target, ability.cast_range, ability.cone_degrees):
					_hit(caster, target, contact, frame, "area")
		E.NOVA:
			for target in state.enemies_of(caster):
				if target.is_alive() and target.position.distance_to(caster.position) \
						<= ability.radius + CombatantState.BODY_RADIUS:
					_hit(caster, target, contact, frame, "area")
		E.DASH:
			pass  # repositions the caster; Magic Behavior (Stage 15)


# --- Projectiles -----------------------------------------------------------------

func _loose(state: BattleState, owner: CombatantState, contact: Dictionary, frame: SimFrame,
		speed: float, radius: float, max_range: float, ability_id: String) -> void:
	var target := state.target_of(owner)
	var direction := owner.facing
	if target != null and target.position.distance_to(owner.position) > 0.01:
		direction = (target.position - owner.position).normalized()
	var start := owner.position + direction * (CombatantState.BODY_RADIUS + radius + 0.05)
	var shot := {
		"id": state.next_projectile_id, "owner": owner.index, "team": owner.team,
		"kind": contact["kind"], "ability": ability_id, "swing": contact.get("swing", 0),
		"combo": contact.get("combo", 0), "position": start, "direction": direction,
		"speed": maxf(speed, 0.1), "radius": radius, "range_left": max_range,
	}
	state.next_projectile_id += 1
	state.projectiles.append(shot)
	frame.emit("projectile", owner.index, owner.target_index, {"id": shot["id"], "ability": ability_id})


## Moves every shot in flight, sweeping its path for bodies and obstacles.
func _fly(state: BattleState, frame: SimFrame) -> void:
	for i in range(state.projectiles.size() - 1, -1, -1):
		var shot := state.projectiles[i]
		var from: Vector2 = shot["position"]
		var travel := minf(float(shot["speed"]) * frame.delta, float(shot["range_left"]))
		var to: Vector2 = from + shot["direction"] * travel
		var struck := _first_body(state, shot, from, to)
		var blocked := not line_clear(state, from, to)
		if struck != null and (not blocked or _nearer(from, struck.position, state, from, to)):
			var owner := state.combatants[shot["owner"]]
			var hit := _hit(owner, struck, {"kind": shot["kind"], "ability": shot["ability"], "swing": shot["swing"],
					"combo": shot["combo"]}, frame, "projectile")
			if hit["outcome"] != "evaded":
				state.projectiles.remove_at(i)
				continue
			shot["passed"] = shot.get("passed", []) + [struck.index]
		if blocked:
			frame.emit("projectile_blocked", shot["owner"], -1, {"id": shot["id"]})
			state.projectiles.remove_at(i)
			continue
		shot["position"] = to
		shot["range_left"] = float(shot["range_left"]) - travel
		if float(shot["range_left"]) <= 0.001 or to.length() > state.layout.radius:
			frame.emit("projectile_faded", shot["owner"], -1, {"id": shot["id"]})
			state.projectiles.remove_at(i)


static func _first_body(state: BattleState, shot: Dictionary, from: Vector2, to: Vector2) -> CombatantState:
	var best: CombatantState = null
	var best_distance := INF
	for target in state.combatants:
		if target.team == shot["team"] or not target.is_alive() or shot.get("passed", []).has(target.index):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(target.position, from, to)
		if closest.distance_to(target.position) <= CombatantState.BODY_RADIUS + float(shot["radius"]):
			var along := from.distance_to(closest)
			if along < best_distance:
				best_distance = along
				best = target
	return best


## Whether a body on the path is reached before the obstacle that blocks it.
static func _nearer(origin: Vector2, body: Vector2, state: BattleState, from: Vector2, to: Vector2) -> bool:
	var body_distance := origin.distance_to(body)
	for obstacle in state.layout.obstacles:
		var centre := Vector2(obstacle.x, obstacle.y)
		var closest := Geometry2D.get_closest_point_to_segment(centre, from, to)
		if closest.distance_to(centre) < obstacle.z and origin.distance_to(closest) < body_distance:
			return false
	return true


# --- Results ---------------------------------------------------------------------

func _hit(attacker: CombatantState, target: CombatantState, contact: Dictionary, frame: SimFrame,
		via: String) -> Dictionary:
	var direction := (target.position - attacker.position)
	direction = direction.normalized() if direction.length() > 0.001 else attacker.facing
	var hit := {
		"attacker": attacker.index, "target": target.index, "kind": contact["kind"],
		"combo": contact.get("combo", 0), "swing": contact.get("swing", 0),
		"ability": contact.get("ability", ""), "direction": direction, "via": via,
	}
	DefenseRules.resolve(attacker, target, hit)
	frame.hits.append(hit)
	frame.emit("hit", attacker.index, target.index, {"kind": hit["kind"], "via": via, "ability": hit["ability"],
			"outcome": hit["outcome"], "perfect": hit["perfect"]})
	match hit["outcome"]:
		"evaded":
			frame.emit("evade", target.index, attacker.index, {"perfect": hit["perfect"], "kind": hit["kind"]})
		"parried":
			frame.emit("parry", target.index, attacker.index, {"kind": hit["kind"]})
		"blocked":
			frame.emit("block", target.index, attacker.index, {"perfect": hit["perfect"], "kind": hit["kind"],
					"guard_drain": snappedf(hit["guard_drain"], 0.01)})
	return hit
