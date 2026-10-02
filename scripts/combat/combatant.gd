class_name Combatant
extends Node3D
## One fighter in the arena (mechanics §47-50, prompts 20-25).
##
## Controllers (player input or AI) only write intents (`move_input`,
## `sprint`, `block_held`) and call `request()`. Everything else — timing,
## stamina, stagger, knockback, dodge and block resolution — happens here and
## in BattleManager, driven by CombatStats so all animals share one model.
## Positions live on the XZ plane; the node is moved kinematically.

signal combat_event(kind: String, data: Dictionary)
signal knocked_out

enum State { FREE, ATTACK, HEAVY, DODGE, BLOCK, HIT, STAGGER, CAST, KO }

const RADIUS := 0.45
const BUFFER_SECONDS := 0.3
const DODGE_SECONDS := 0.42
const STAGGER_SECONDS := 1.0
const GUARD_BREAK_SECONDS := 1.15
const PARRY_SECONDS := 0.55
const RIPOSTE_WINDOW := 0.75
const STAGGER_DECAY := 16.0
## Fraction of each normalized clip at which its strike lands.
const IMPACT := {"attack": 0.42, "heavy_attack": 0.56, "cast": 0.6}

var display_name := ""
var team := 0
var is_player := false
var stats: CombatStats
var weapon: WeaponData
var armor: ArmorData
var ability: MagicAbilityData
var ability_rank := 0
var techniques: Array[String] = []
## Multiplier on attack wind-ups (tutorial opponents telegraph more).
var telegraph := 1.0

var health := 100.0
var stamina := 100.0
var state: State = State.FREE
var phase := ""           # attack/cast phase: windup, active, recovery
var phase_time := 0.0
var state_time := 0.0
var state_duration := 0.0
var facing := 0.0         # yaw; forward is (-sin, 0, -cos)
var velocity := Vector3.ZERO
var push := Vector3.ZERO
var stagger_meter := 0.0
var exhausted_time := 0.0
var regen_delay := 0.0
var cooldown := 0.0
var combo_index := 0
var current_attack: Dictionary = {}
var dodge_direction := Vector3.ZERO
var dodge_distance := 0.0
var dodge_started := -10.0
var block_started := -10.0
var last_block_success := -10.0
var burn_time := 0.0
var burn_dps := 0.0
var low_health_reached := false

var target: Combatant
var battle: BattleManager
var visual: CharacterVisual

# Intents written by controllers.
var move_input := Vector2.ZERO
var sprint := false
var block_held := false

var _buffered := ""
var _buffer_time := 0.0


# --- Setup ---------------------------------------------------------------------

func setup_from_champion(champion: Champion) -> void:
	display_name = champion.name
	stats = CombatStats.for_champion(champion)
	weapon = Content.weapon(champion.weapon_id)
	armor = Content.armor(champion.armor_id)
	ability = Content.ability(champion.equipped_ability)
	if ability != null:
		ability_rank = champion.skills.get_rank("magic:" + ability.school)
		if ability_rank < ability.required_rank:
			ability = null
	techniques = champion.techniques.duplicate()
	if Settings.get_value("combat_assist"):
		stats.perfect_window += 0.06  # accessibility: wider timing windows
	_reset_pools()


func setup_from_opponent(opponent: OpponentData) -> void:
	display_name = opponent.display_name
	stats = CombatStats.for_opponent(opponent)
	weapon = Content.weapon(opponent.weapon_id)
	armor = Content.armor(opponent.armor_id)
	ability = Content.ability(opponent.magic_ability_id)
	if ability != null:
		ability_rank = int(opponent.skills.get("magic:" + ability.school, ability.required_rank))
	telegraph = opponent.telegraph * (1.3 if Settings.get_value("combat_assist") else 1.0)
	_reset_pools()


func _reset_pools() -> void:
	health = stats.max_health
	stamina = stats.max_stamina
	state = State.FREE


# --- Queries -------------------------------------------------------------------

func forward() -> Vector3:
	return Vector3(-sin(facing), 0.0, -cos(facing))


func planar_position() -> Vector3:
	return Vector3(position.x, 0.0, position.z)


func is_alive() -> bool:
	return state != State.KO


func is_exhausted() -> bool:
	return exhausted_time > 0.0


func is_invulnerable() -> bool:
	return state == State.DODGE and state_time <= stats.dodge_iframes


func is_blocking() -> bool:
	return state == State.BLOCK


## True while committed to an attack/cast recovery: the window to punish.
func is_recovering() -> bool:
	return ((state == State.ATTACK or state == State.HEAVY or state == State.CAST) and phase == "recovery") \
			or state == State.STAGGER


func is_winding_up() -> bool:
	return (state == State.ATTACK or state == State.HEAVY or state == State.CAST) and phase == "windup"


func health_ratio() -> float:
	return health / stats.max_health


func stamina_ratio() -> float:
	return stamina / stats.max_stamina


## Heavy weapons commit to their heavy swings: light blows cannot flinch
## them out of the wind-up (poise still builds toward a stagger).
func has_hyper_armor() -> bool:
	return state == State.HEAVY and phase == "windup" and weapon != null and weapon.weight >= 5.0


func knows(technique_id: String) -> bool:
	return techniques.has(technique_id)


func magic_ready() -> bool:
	return ability != null and cooldown <= 0.0


# --- Intents -------------------------------------------------------------------

## Buffers an action ("attack", "heavy", "dodge", "magic") briefly so taps
## during a recovery are not lost.
func request(action: String) -> void:
	if not is_alive():
		return
	_buffered = action
	_buffer_time = BUFFER_SECONDS


# --- Simulation ------------------------------------------------------------------

func tick(delta: float) -> void:
	if state == State.KO:
		_move_with_push(delta, Vector3.ZERO)
		return
	state_time += delta
	phase_time += delta
	_buffer_time -= delta
	if _buffer_time <= 0.0:
		_buffered = ""
	cooldown = maxf(cooldown - delta, 0.0)
	stagger_meter = maxf(stagger_meter - STAGGER_DECAY * delta, 0.0)
	_tick_stamina(delta)
	_tick_burn(delta)
	match state:
		State.FREE, State.BLOCK:
			_tick_free(delta)
		State.ATTACK, State.HEAVY:
			_tick_attack(delta)
		State.DODGE:
			_tick_dodge(delta)
		State.CAST:
			_tick_cast(delta)
		State.HIT, State.STAGGER:
			_move_with_push(delta, Vector3.ZERO)
			if state_time >= state_duration:
				_enter_free()


func _tick_stamina(delta: float) -> void:
	if exhausted_time > 0.0:
		exhausted_time -= delta
		if exhausted_time <= 0.0:
			_emit("recovered_breath")
	regen_delay -= delta
	var sprinting := state == State.FREE and sprint and velocity.length() > 0.5 and not is_exhausted()
	if sprinting:
		stamina = maxf(stamina - stats.sprint_stamina * delta, 0.0)
		regen_delay = maxf(regen_delay, 0.2)
		if stamina <= 0.0:
			_become_exhausted()
	elif state == State.BLOCK:
		stamina = maxf(stamina - stats.block_drain * delta, 0.0)
		if stamina <= 0.0:
			_guard_break(null)
	elif regen_delay <= 0.0:
		var rate := stats.stamina_regen * (1.2 if exhausted_time > 0.0 else 1.0)
		stamina = minf(stamina + rate * delta, stats.max_stamina)


func _tick_burn(delta: float) -> void:
	if burn_time <= 0.0:
		return
	burn_time -= delta
	_take_damage(burn_dps * delta, null)


func _tick_free(delta: float) -> void:
	_face_target(delta, 1.0)
	# Consume buffered actions.
	if not _buffered.is_empty():
		var action := _buffered
		if _try_action(action):
			_buffered = ""
			return
	# Block (held).
	if block_held and not is_exhausted() and stamina > 1.0:
		if state != State.BLOCK:
			state = State.BLOCK
			state_time = 0.0
			block_started = battle.time if battle else 0.0
			_play("block", -1.0, false)
	elif state == State.BLOCK:
		_enter_free()
	var speed := stats.move_speed
	if is_exhausted():
		speed *= Content.config.exhausted_speed_factor
	elif sprint and stamina > 1.0 and state == State.FREE:
		speed *= Content.config.sprint_factor
	if state == State.BLOCK:
		speed *= 0.4
	var desired := Vector3(move_input.x, 0.0, move_input.y).limit_length(1.0) * speed
	velocity = velocity.lerp(desired, clampf(delta * 12.0, 0.0, 1.0))
	_move_with_push(delta, velocity)
	if visual != null and state == State.FREE:
		if is_exhausted():
			if visual.current_clip() != visual.resolve_clip("exhausted"):
				visual.play("exhausted", -1.0, false)
		else:
			if visual.current_clip() == visual.resolve_clip("exhausted"):
				visual.release()
			visual.set_locomotion(velocity.length() / maxf(stats.move_speed * 1.2, 0.1), true)


func _try_action(action: String) -> bool:
	match action:
		"attack":
			return start_attack(false)
		"heavy":
			return start_attack(true)
		"dodge":
			return start_dodge()
		"magic":
			return start_cast()
	return false


func _tick_attack(delta: float) -> void:
	_move_with_push(delta, forward() * (0.9 if phase == "active" else 0.0))
	match phase:
		"windup":
			_face_target(delta, 0.35)
			if phase_time >= current_attack["windup"]:
				phase = "active"
				phase_time = 0.0
				if battle != null:
					battle.resolve_attack(self, current_attack)
		"active":
			if phase_time >= current_attack["active"]:
				phase = "recovery"
				phase_time = 0.0
		"recovery":
			# Combos: a buffered attack during recovery continues the chain.
			if _buffered == "attack" and state == State.ATTACK and combo_index + 1 < stats.combo_max:
				_buffered = ""
				combo_index += 1
				_begin_attack(false)
				return
			if _buffered == "dodge":
				_buffered = ""
				if start_dodge():
					return
			if phase_time >= current_attack["recovery"]:
				combo_index = 0
				_enter_free()


func _tick_dodge(delta: float) -> void:
	var travel_time := DODGE_SECONDS * 0.75
	var speed := 0.0
	if state_time <= travel_time:
		# Ease-out: fast at the start, settling at the end.
		speed = dodge_distance / travel_time * 2.0 * (1.0 - state_time / travel_time)
	_move_with_push(delta, dodge_direction * speed)
	if state_time >= state_duration:
		_enter_free()


func _tick_cast(delta: float) -> void:
	_move_with_push(delta, Vector3.ZERO)
	match phase:
		"windup":
			_face_target(delta, 0.6)
			if phase_time >= current_attack["windup"]:
				phase = "recovery"
				phase_time = 0.0
				if battle != null:
					battle.release_ability(self, ability)
		"recovery":
			if phase_time >= current_attack["recovery"]:
				_enter_free()


# --- Actions ---------------------------------------------------------------------

func can_spend(_amount: float) -> bool:
	return not is_exhausted() and stamina >= 1.0


## Spends stamina; dropping to zero exhausts the champion (mechanics §47).
func spend(amount: float) -> void:
	stamina -= amount
	regen_delay = Content.config.stamina_regen_delay
	if stamina <= 0.0:
		stamina = 0.0
		_become_exhausted()


func _become_exhausted() -> void:
	if exhausted_time > 0.0:
		return
	exhausted_time = stats.exhaustion_seconds
	_emit("exhausted")


func start_attack(heavy: bool) -> bool:
	if not (state == State.FREE or state == State.BLOCK):
		return false
	var cost := stats.heavy_stamina if heavy else stats.attack_stamina
	if not can_spend(cost):
		_emit("too_tired")
		return false
	combo_index = 0
	return _begin_attack(heavy)


func _begin_attack(heavy: bool) -> bool:
	var cost := stats.heavy_stamina if heavy else stats.attack_stamina
	var technique := ""
	var damage := stats.heavy_damage if heavy else stats.damage * (1.0 + combo_index * 0.1)
	var windup := (stats.heavy_windup if heavy else stats.windup) * telegraph
	var recovery := stats.heavy_recovery if heavy else stats.recovery
	var now := battle.time if battle else 0.0
	if not heavy and combo_index == 0 and knows("riposte") and now - last_block_success <= RIPOSTE_WINDOW:
		var riposte := Content.technique("riposte")
		technique = "riposte"
		damage *= riposte.power
		windup *= 0.5
		cost += riposte.stamina_cost * 0.5
	if heavy and ability != null and ability.school == "fire" and knows("flame_slash"):
		var flame := Content.technique("flame_slash")
		technique = "flame_slash"
		damage *= flame.power
		cost += flame.stamina_cost
	if combo_index > 0:
		windup *= 0.85
	if is_exhausted():
		windup *= 1.3
		recovery *= 1.3
	spend(cost)
	state = State.HEAVY if heavy else State.ATTACK
	state_time = 0.0
	phase = "windup"
	phase_time = 0.0
	current_attack = {
		"heavy": heavy, "damage": damage, "windup": windup, "active": stats.active, "recovery": recovery,
		"stagger": stats.heavy_stagger_power if heavy else stats.stagger_power,
		"knockback": stats.knockback_power * (1.8 if heavy else 1.0),
		"guard_pressure": stats.guard_pressure * (1.6 if heavy else 1.0),
		"combo": combo_index, "technique": technique, "kind": "melee",
		"burn": technique == "flame_slash",
		"in_range_at_start": target != null and _in_reach(target),
	}
	var clip := "heavy_attack" if heavy else "attack"
	_play(clip, windup / IMPACT[clip])
	Sfx.play("heavy_swing" if heavy else "swing")
	return true


func start_dodge() -> bool:
	if not (state == State.FREE or state == State.BLOCK or (state in [State.ATTACK, State.HEAVY] and phase == "recovery")):
		return false
	if not can_spend(stats.dodge_stamina):
		_emit("too_tired")
		return false
	spend(stats.dodge_stamina)
	var direction := Vector3(move_input.x, 0.0, move_input.y)
	if direction.length() < 0.2:
		direction = -forward()  # back-step away from the opponent
	dodge_direction = direction.normalized()
	dodge_distance = stats.dodge_distance
	if ability != null and ability.school == "wind" and knows("wind_dash"):
		dodge_distance *= Content.technique("wind_dash").power
	state = State.DODGE
	state_time = 0.0
	state_duration = DODGE_SECONDS + stats.dodge_recovery
	dodge_started = battle.time if battle else 0.0
	combo_index = 0
	_play("dodge", state_duration)
	Sfx.play("dodge")
	return true


func start_cast() -> bool:
	if ability == null or not (state == State.FREE or state == State.BLOCK):
		return false
	if cooldown > 0.0:
		_emit("not_ready")
		return false
	if not can_spend(ability.stamina_cost):
		_emit("too_tired")
		return false
	spend(ability.stamina_cost)
	cooldown = ability.cooldown
	var mastery := clampf(1.0 - (ability_rank - ability.required_rank) * 0.05, 0.7, 1.0)
	state = State.CAST
	state_time = 0.0
	phase = "windup"
	phase_time = 0.0
	current_attack = {"windup": ability.cast_time * mastery * (1.3 if is_exhausted() else 1.0),
			"recovery": ability.recovery, "kind": "magic"}
	_play("cast", current_attack["windup"] / IMPACT["cast"])
	Sfx.play("cast")
	_emit("cast_started", {"ability": ability.id})
	return true


# --- Being hit ---------------------------------------------------------------------

## Resolves an incoming attack. Returns the outcome:
## evaded, perfect_evade, blocked, perfect_block, guard_break, hit, stagger, ko.
func receive_attack(attacker: Combatant, info: Dictionary) -> String:
	if not is_alive():
		return "none"
	var now := battle.time if battle else 0.0
	var heavy: bool = info.get("heavy", false)
	var magic: bool = info.get("kind", "melee") == "magic"
	if is_invulnerable():
		var perfect := now - dodge_started <= stats.perfect_window
		var outcome := "perfect_evade" if perfect else "evaded"
		_emit("evaded", {"perfect": perfect, "heavy": heavy, "magic": magic})
		Sfx.play("perfect_dodge" if perfect else "dodge")
		return outcome
	var from := attacker.planar_position() if attacker != null else planar_position() + forward()
	var to_attacker := (from - planar_position()).normalized()
	var facing_attacker := forward().dot(to_attacker) > cos(deg_to_rad(110.0))
	var damage: float = info.get("damage", 0.0)
	if is_blocking() and facing_attacker:
		var perfect := now - block_started <= stats.perfect_window
		if perfect:
			last_block_success = now
			_emit("blocked", {"perfect": true, "heavy": heavy, "magic": magic})
			Sfx.play("perfect_block")
			if attacker != null and not magic:
				attacker.parried()
			return "perfect_block"
		var guard_breaker: bool = heavy and attacker != null and attacker.knows("guard_break") and not magic
		var drain := damage * float(info.get("guard_pressure", 1.0)) * 0.35
		stamina = maxf(stamina - drain, 0.0)
		regen_delay = Content.config.stamina_regen_delay
		_take_damage(damage * stats.block_factor, attacker)
		_apply_push(to_attacker * -1.0, float(info.get("knockback", 1.0)) * 0.4)
		if guard_breaker or stamina <= 0.0:
			_guard_break(attacker, guard_breaker)
			return "guard_break"
		last_block_success = now
		_emit("blocked", {"perfect": false, "heavy": heavy, "magic": magic})
		Sfx.play("block")
		if visual != null:
			visual.flash(Color(0.6, 0.8, 1.0), 0.08)
		return "blocked"
	# Clean hit.
	var dealt := damage * (1.0 - stats.mitigation)
	var punished := is_recovering() or is_winding_up()
	_take_damage(dealt, attacker)
	if info.get("burn_dps", 0.0) > 0.0:
		burn_dps = info["burn_dps"]
		burn_time = info.get("burn_seconds", 2.0)
	elif info.get("burn", false):
		burn_dps = 4.0
		burn_time = 2.5
	_emit("damaged", {"amount": dealt, "heavy": heavy, "magic": magic, "punished": punished})
	if not is_alive():
		return "ko"
	_apply_push(to_attacker * -1.0, float(info.get("knockback", 1.0)))
	stagger_meter += float(info.get("stagger", 0.0)) * stats.stagger_taken
	var interrupted := state == State.CAST and phase == "windup" and ability != null and ability.interruptible
	if heavy or stagger_meter >= stats.poise:
		stagger_meter = 0.0
		_enter_stun(State.STAGGER, STAGGER_SECONDS * stats.stagger_taken + (0.2 if heavy else 0.0), "stagger")
		Sfx.play("heavy_hit" if heavy else "stagger")
		if interrupted:
			_emit("interrupted")
		return "stagger"
	if has_hyper_armor():
		Sfx.play("block")
		_emit("armored", {})
		return "hit"
	_enter_stun(State.HIT, stats.hit_recovery, "hit")
	Sfx.play("hit")
	if interrupted:
		_emit("interrupted")
	return "hit"


## Perfect block reflects the impact back into the attacker's stance.
func parried() -> void:
	if is_alive():
		_enter_stun(State.STAGGER, PARRY_SECONDS, "stagger")


func _guard_break(attacker: Combatant, by_technique: bool = false) -> void:
	stamina = 0.0
	_become_exhausted()
	_enter_stun(State.STAGGER, GUARD_BREAK_SECONDS, "stagger")
	Sfx.play("guard_break")
	_emit("guard_broken", {"technique": by_technique, "attacker": attacker})


func _take_damage(amount: float, _attacker: Combatant) -> void:
	if amount <= 0.0 or not is_alive():
		return
	health = maxf(health - amount, 0.0)
	if visual != null:
		visual.flash(Color(1.0, 0.45, 0.35))
	if health <= 0.0:
		_knock_out()
	elif health_ratio() < 0.25 and not low_health_reached:
		low_health_reached = true
		_emit("low_health")


func _knock_out() -> void:
	state = State.KO
	state_time = 0.0
	phase = ""
	burn_time = 0.0
	_play("knocked_out", -1.0)
	Sfx.play("knockout")
	knocked_out.emit()


func _enter_stun(new_state: State, duration: float, clip: String) -> void:
	state = new_state
	state_time = 0.0
	state_duration = duration
	phase = ""
	combo_index = 0
	_buffered = ""
	_play(clip, duration)


func _enter_free() -> void:
	state = State.FREE
	state_time = 0.0
	phase = ""
	if visual != null:
		visual.release()


func _apply_push(direction: Vector3, strength: float) -> void:
	push += direction.normalized() * strength * 3.2 * stats.knockback_taken


# --- Movement --------------------------------------------------------------------

func _face_target(delta: float, factor: float) -> void:
	if target == null:
		return
	var to := target.planar_position() - planar_position()
	if to.length() < 0.01:
		return
	var desired := atan2(-to.x, -to.z)
	facing = rotate_toward(facing, desired, stats.turn_speed * factor * delta)
	rotation.y = facing


func _move_with_push(delta: float, move_velocity: Vector3) -> void:
	position += (move_velocity + push) * delta
	push = push.lerp(Vector3.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	if battle != null:
		battle.constrain(self)


func _in_reach(other: Combatant) -> bool:
	var to := other.planar_position() - planar_position()
	return to.length() <= stats.attack_range + RADIUS


func _play(clip: String, duration: float, lock: bool = true) -> void:
	if visual != null:
		visual.play(clip, duration, lock)


func _emit(kind: String, data: Dictionary = {}) -> void:
	combat_event.emit(kind, data)
