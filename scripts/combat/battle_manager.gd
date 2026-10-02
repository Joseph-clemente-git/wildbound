class_name BattleManager
extends Node3D
## Runs one 1v1 trial: steps controllers and combatants, resolves attacks,
## Aether Arts and projectiles, keeps fighters inside the arena and decides
## the result. Steps can be driven manually (`auto_step = false`) so tests
## and replays are deterministic.

signal hint(text: String)
signal floating_text(world_position: Vector3, text: String, color: Color)
## Relayed combat events: who, kind, data (consumed by experience + UI).
signal combat_event(who: Combatant, kind: String, data: Dictionary)
signal ended(winner: Combatant)

const MAX_SECONDS := 240.0

var time := 0.0
var arena_radius := 11.0
var obstacles: Array[Vector4] = []
var player: Combatant
var opponent: Combatant
var player_controller: Object   # anything with update(delta)
var ai: AiController
var running := false
var finished := false
var auto_step := true
var winner: Combatant
## Effects hook: Callable(ability, caster, data) for presentation (optional).
var effect_spawner: Callable

var _projectiles: Array[Dictionary] = []


func setup(arena: ArenaData, player_fighter: Combatant, opponent_fighter: Combatant) -> void:
	arena_radius = arena.radius if arena != null else 11.0
	obstacles = arena.obstacles.duplicate() if arena != null else ([] as Array[Vector4])
	player = player_fighter
	opponent = opponent_fighter
	player.is_player = true
	player.team = 0
	opponent.team = 1
	for fighter: Combatant in [player, opponent]:
		fighter.battle = self
		fighter.combat_event.connect(_relay.bind(fighter))
		fighter.knocked_out.connect(_on_knocked_out.bind(fighter))
	player.target = opponent
	opponent.target = player
	if arena != null and not arena.player_spawns.is_empty():
		player.position = arena.player_spawns[0]
		opponent.position = arena.opponent_spawns[0]
	_face_each_other()


func _face_each_other() -> void:
	for fighter: Combatant in [player, opponent]:
		var to := fighter.target.planar_position() - fighter.planar_position()
		fighter.facing = atan2(-to.x, -to.z)
		fighter.rotation.y = fighter.facing


func start() -> void:
	running = true


func _physics_process(delta: float) -> void:
	if auto_step and running and not finished:
		step(delta)


func step(delta: float) -> void:
	if finished:
		return
	time += delta
	if player_controller != null:
		player_controller.update(delta)
	if ai != null:
		ai.update(delta)
	player.tick(delta)
	opponent.tick(delta)
	_tick_projectiles(delta)
	_separate()
	if time >= MAX_SECONDS and not finished:
		# Judges decide on remaining health.
		_finish(player if player.health_ratio() >= opponent.health_ratio() else opponent)


# --- Melee ---------------------------------------------------------------------

func resolve_attack(attacker: Combatant, info: Dictionary) -> void:
	var defender := attacker.target
	if defender == null or not defender.is_alive():
		return
	var to := defender.planar_position() - attacker.planar_position()
	var distance := to.length()
	var reach := attacker.stats.attack_range + Combatant.RADIUS
	var angle := rad_to_deg(attacker.forward().angle_to(to.normalized())) if distance > 0.01 else 0.0
	if distance > reach or angle > attacker.stats.arc_degrees * 0.5:
		if info.get("in_range_at_start", false) and not defender.is_invulnerable() and not defender.is_blocking():
			# The defender moved out of an attack that would have landed.
			_relay("repositioned", {}, defender)
		_relay("whiffed", {"heavy": info.get("heavy", false)}, attacker)
		return
	var punish := defender.is_recovering() or defender.is_winding_up()
	var outcome := defender.receive_attack(attacker, info)
	_report_outcome(attacker, defender, outcome, info, punish)


func _report_outcome(attacker: Combatant, defender: Combatant, outcome: String, info: Dictionary, punish: bool) -> void:
	var data := info.duplicate()
	data["outcome"] = outcome
	data["punish"] = punish
	_relay("attack_result", data, attacker)
	var spot := defender.global_position + Vector3(0, 2.0, 0) if defender.is_inside_tree() else defender.position
	match outcome:
		"perfect_evade":
			floating_text.emit(spot, "Perfect dodge!", UiTheme.AETHER)
		"evaded":
			floating_text.emit(spot, "Dodged", UiTheme.TEXT_DIM)
		"perfect_block":
			floating_text.emit(spot, "Perfect block!", UiTheme.AETHER)
		"blocked":
			floating_text.emit(spot, "Blocked", UiTheme.TEXT_DIM)
		"guard_break":
			floating_text.emit(spot, "Guard broken!", UiTheme.WARN)
		"stagger":
			floating_text.emit(spot, "Staggered!", UiTheme.WARN)
	if not str(info.get("technique", "")).is_empty() and outcome in ["hit", "stagger", "ko", "guard_break"]:
		var technique := Content.technique(info["technique"])
		floating_text.emit(spot + Vector3(0, 0.4, 0), technique.display_name + "!", UiTheme.ACCENT)
		_relay("technique_used", {"technique": technique.id}, attacker)


# --- Aether Arts ------------------------------------------------------------------

func release_ability(caster: Combatant, ability: MagicAbilityData) -> void:
	if ability == null:
		return
	var school_power := 1.0 + (caster.ability_rank - ability.required_rank) * 0.06
	var info := {
		"kind": "magic", "school": ability.school, "ability": ability.id,
		"damage": ability.damage * school_power, "knockback": ability.knockback,
		"stagger": ability.stagger, "heavy": false,
		"burn_dps": ability.burn_dps, "burn_seconds": ability.burn_seconds, "guard_pressure": 0.8,
	}
	_relay("cast_released", {"ability": ability.id, "school": ability.school}, caster)
	match ability.effect:
		MagicAbilityData.Effect.PROJECTILE:
			var origin := caster.planar_position() + caster.forward() * 0.7
			var projectile := {"position": origin, "direction": caster.forward(), "speed": ability.speed,
					"remaining": ability.cast_range, "radius": ability.radius, "info": info,
					"owner": caster, "node": null}
			if effect_spawner.is_valid():
				projectile["node"] = effect_spawner.call(ability, caster, projectile)
			_projectiles.append(projectile)
		MagicAbilityData.Effect.CONE_PUSH:
			_area_effect(caster, info, ability.cast_range, ability.cone_degrees)
			if effect_spawner.is_valid():
				effect_spawner.call(ability, caster, {})
		MagicAbilityData.Effect.NOVA:
			_area_effect(caster, info, ability.radius, 360.0)
			if effect_spawner.is_valid():
				effect_spawner.call(ability, caster, {})
		MagicAbilityData.Effect.DASH:
			var direction := Vector3(caster.move_input.x, 0, caster.move_input.y)
			if direction.length() < 0.2:
				direction = caster.forward()
			caster.dodge_direction = direction.normalized()
			caster.dodge_distance = ability.speed
			caster.state = Combatant.State.DODGE
			caster.state_time = 0.0
			caster.state_duration = Combatant.DODGE_SECONDS + 0.1
			caster.dodge_started = time
			if effect_spawner.is_valid():
				effect_spawner.call(ability, caster, {})


func _area_effect(caster: Combatant, info: Dictionary, reach: float, cone: float) -> void:
	var defender := caster.target
	if defender == null or not defender.is_alive():
		return
	var to := defender.planar_position() - caster.planar_position()
	var angle := rad_to_deg(caster.forward().angle_to(to.normalized())) if to.length() > 0.01 else 0.0
	if to.length() <= reach + Combatant.RADIUS and angle <= cone * 0.5:
		_report_magic(caster, defender, info)
	else:
		_relay("magic_missed", info, caster)


func _report_magic(caster: Combatant, defender: Combatant, info: Dictionary) -> void:
	var punish := defender.is_recovering() or defender.is_winding_up()
	var outcome := defender.receive_attack(caster, info)
	_report_outcome(caster, defender, outcome, info, punish)


func _tick_projectiles(delta: float) -> void:
	for projectile: Dictionary in _projectiles.duplicate():
		var step_length: float = projectile["speed"] * delta
		projectile["position"] += projectile["direction"] * step_length
		projectile["remaining"] -= step_length
		var node: Node3D = projectile["node"]
		if node != null and is_instance_valid(node):
			node.position = projectile["position"] + Vector3(0, 1.1, 0)
		var owner_fighter: Combatant = projectile["owner"]
		var defender := owner_fighter.target
		var done: bool = projectile["remaining"] <= 0.0 or (projectile["position"] as Vector3).length() > arena_radius + 2.0
		if not done and defender != null and defender.is_alive():
			var gap := (defender.planar_position() - (projectile["position"] as Vector3)).length()
			if gap <= float(projectile["radius"]) + Combatant.RADIUS:
				_report_magic(owner_fighter, defender, projectile["info"])
				done = true
		if done:
			if node != null and is_instance_valid(node):
				if node.has_method("burst"):
					node.burst()
				else:
					node.queue_free()
			if projectile["remaining"] <= 0.0:
				_relay("magic_missed", projectile["info"], owner_fighter)
			_projectiles.erase(projectile)


## Incoming projectiles aimed at `fighter` (for AI reactions).
func projectiles_toward(fighter: Combatant, within: float) -> int:
	var count := 0
	for projectile: Dictionary in _projectiles:
		if projectile["owner"] == fighter:
			continue
		var to := fighter.planar_position() - (projectile["position"] as Vector3)
		if to.length() < within and to.normalized().dot(projectile["direction"]) > 0.8:
			count += 1
	return count


# --- Space ----------------------------------------------------------------------

## Keeps a fighter inside the ring and outside obstacles.
func constrain(fighter: Combatant) -> void:
	var flat := fighter.planar_position()
	var limit := arena_radius - Combatant.RADIUS
	if flat.length() > limit:
		flat = flat.normalized() * limit
		fighter.push = fighter.push.slide(flat.normalized()) * 0.5
	for obstacle: Vector4 in obstacles:
		var center := Vector3(obstacle.x, 0, obstacle.y)
		var offset := flat - center
		var min_distance := obstacle.z + Combatant.RADIUS
		if offset.length() < min_distance:
			flat = center + (offset.normalized() if offset.length() > 0.001 else Vector3.RIGHT) * min_distance
	fighter.position = Vector3(flat.x, fighter.position.y, flat.z)


func _separate() -> void:
	var offset := opponent.planar_position() - player.planar_position()
	var min_distance := Combatant.RADIUS * 2.0
	if offset.length() < min_distance:
		var correction := (offset.normalized() if offset.length() > 0.001 else Vector3.FORWARD) \
				* (min_distance - offset.length()) * 0.5
		player.position -= correction
		opponent.position += correction
		constrain(player)
		constrain(opponent)


# --- Flow --------------------------------------------------------------------------

func _relay(kind: String, data: Dictionary, who: Combatant) -> void:
	combat_event.emit(who, kind, data)


func _on_knocked_out(fighter: Combatant) -> void:
	_finish(fighter.target)


func _finish(winning: Combatant) -> void:
	if finished:
		return
	finished = true
	running = false
	winner = winning
	ended.emit(winning)
