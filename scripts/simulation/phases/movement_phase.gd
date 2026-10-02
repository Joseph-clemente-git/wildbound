class_name MovementPhase
extends SimulationPhase
## Position Update: turns intents and actions into motion on the arena floor.
##
## - Speed comes from derived move speed (Agility, armor, weapon weight,
##   movement skill) and what the combatant is doing: full while free, slowed
##   while guarding or winding up, planted while an attack lands or recovers.
## - Responsiveness — how fast it reaches that speed or changes direction —
##   grows with Agility.
## - Turning toward the target uses the derived turn speed and is limited
##   while committed to an attack.
## - A dodge covers its dodge distance during its protected window, then stops.
## - Knockback pushes (Stage 13) slide out on their own, apart from walking.
## - The ring edge, obstacles and other bodies stop movement.
##
## Every body moves by the same rules; terrain and movement-type differences
## (water, air, elevation) plug in through `terrain_speed`.

const A := CombatantState.Action
const P := CombatantState.Phase
const MOVING_SPEED := 0.2
## How quickly a push slides out (m/s²).
const PUSH_FRICTION := 9.0


func _init() -> void:
	super("movement")


func run(state: BattleState, frame: SimFrame) -> void:
	for fighter in state.combatants:
		if not fighter.is_alive():
			fighter.velocity = Vector2.ZERO
			continue
		var intent: Dictionary = frame.intents.get(fighter.index, {})
		_turn(state, fighter, frame.delta)
		_accelerate(state, fighter, intent, frame.delta)
		fighter.position += (fighter.velocity + fighter.push_velocity) * frame.delta
		fighter.push_velocity = fighter.push_velocity.move_toward(Vector2.ZERO, PUSH_FRICTION * frame.delta)
		_constrain(state, fighter)
		if fighter.action == A.IDLE or fighter.action == A.MOVE:
			fighter.action = A.MOVE if fighter.velocity.length() > MOVING_SPEED else A.IDLE
	_separate(state)


## Acceleration (m/s²): how quickly a combatant answers a change of plan.
static func responsiveness(fighter: CombatantState) -> float:
	var config := Content.config
	return config.simulation_accel_base + fighter.spec.get_stat("agility") * config.simulation_accel_per_agility


## Fraction of move speed allowed by what the combatant is doing.
static func speed_factor(fighter: CombatantState) -> float:
	var config := Content.config
	match fighter.action:
		A.IDLE, A.MOVE:
			return 1.0
		A.BLOCK:
			return config.simulation_block_move_factor
		A.ATTACK, A.HEAVY:
			return config.simulation_attack_move_factor if fighter.phase == P.WINDUP else 0.0
	return 0.0


## Ground everywhere for now. Water, air and elevation zones will change
## speed here by movement type, never by species.
static func terrain_speed(_state: BattleState, _fighter: CombatantState) -> float:
	return 1.0


func _accelerate(state: BattleState, fighter: CombatantState, intent: Dictionary, delta: float) -> void:
	var derived := fighter.spec.derived
	if fighter.action == A.DODGE:
		if fighter.phase == P.ACTIVE:
			var dodge_time := maxf(derived.dodge_iframes, 0.05)
			fighter.velocity = fighter.dodge_direction * (derived.dodge_distance / dodge_time)
		else:
			fighter.velocity = Vector2.ZERO
		return
	var accel := responsiveness(fighter)
	if fighter.action in ActionPhase.HELD_STATES:
		fighter.velocity = fighter.velocity.move_toward(Vector2.ZERO, accel * delta)
		return
	var wanted: Vector2 = intent.get("move", Vector2.ZERO)
	var desired := wanted.limit_length(1.0) * derived.move_speed * speed_factor(fighter) * terrain_speed(state, fighter)
	if fighter.is_exhausted():
		desired *= Content.config.exhausted_speed_factor
	fighter.velocity = fighter.velocity.move_toward(desired, accel * delta)


func _turn(state: BattleState, fighter: CombatantState, delta: float) -> void:
	var target := state.target_of(fighter)
	if target == null or target.position.distance_to(fighter.position) < 0.01:
		return
	var desired := (target.position - fighter.position).normalized()
	var rate := fighter.spec.derived.turn_speed
	if fighter.action in [A.ATTACK, A.HEAVY] and fighter.phase != P.WINDUP:
		rate *= Content.config.simulation_committed_turn_factor
	elif fighter.action == A.CAST or fighter.action in ActionPhase.HELD_STATES:
		rate *= Content.config.simulation_committed_turn_factor
	var angle := fighter.facing.angle_to(desired)
	fighter.facing = fighter.facing.rotated(clampf(angle, -rate * delta, rate * delta)).normalized()


func _constrain(state: BattleState, fighter: CombatantState) -> void:
	var body := CombatantState.BODY_RADIUS
	for obstacle in state.layout.obstacles:
		var centre := Vector2(obstacle.x, obstacle.y)
		var offset := fighter.position - centre
		var reach := obstacle.z + body
		if offset.length() < reach:
			var normal := offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
			fighter.position = centre + normal * reach
			_stop_into(fighter, normal)
	var limit := state.layout.radius - body
	if fighter.position.length() > limit:
		var outward := fighter.position.normalized()
		fighter.position = outward * limit
		_stop_into(fighter, -outward)


## Removes the part of the velocity pushing into a surface whose normal
## points back toward open ground.
static func _stop_into(fighter: CombatantState, normal: Vector2) -> void:
	var into := fighter.velocity.dot(normal)
	if into < 0.0:
		fighter.velocity -= normal * into
	var pushed := fighter.push_velocity.dot(normal)
	if pushed < 0.0:
		fighter.push_velocity -= normal * pushed


func _separate(state: BattleState) -> void:
	var minimum := CombatantState.BODY_RADIUS * 2.0
	for a in state.combatants:
		if not a.is_alive():
			continue
		for b in state.combatants:
			if b.index <= a.index or not b.is_alive():
				continue
			var offset := b.position - a.position
			var distance := offset.length()
			if distance >= minimum:
				continue
			var normal := offset / distance if distance > 0.001 else Vector2.RIGHT.rotated(a.index)
			var push := (minimum - distance) * 0.5
			a.position -= normal * push
			b.position += normal * push
			_constrain(state, a)
			_constrain(state, b)
