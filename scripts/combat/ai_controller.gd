class_name AiController
extends RefCounted
## Opponent behaviour driven entirely by OpponentData (no per-animal code).
##
## The AI observes the player with a reaction delay, chooses to dodge, block,
## reposition, attack or cast according to its profile, manages its stamina,
## and switches behaviour phases at health thresholds — which is how the first
## trial teaches dodging, timing and stamina one at a time (story §20).

const DECISION_SECONDS := 0.22

var me: Combatant
var enemy: Combatant
var battle: BattleManager
var profile: OpponentData
var params: Dictionary = {}
var phase_index := -1
var rng := RandomNumberGenerator.new()

var _decision_timer := 0.0
var _block_timer := 0.0
var _strafe := 1.0
var _strafe_timer := 0.0
var _threat_seen := false
var _react_at := 0.0
var _reaction := ""
var _retreating := false


func _init(fighter: Combatant, opponent_profile: OpponentData, seed_value: int = 0) -> void:
	me = fighter
	enemy = fighter.target
	battle = fighter.battle
	profile = opponent_profile
	rng.seed = seed_value if seed_value != 0 else hash(opponent_profile.id)
	params = {
		"aggression": profile.aggression, "block_skill": profile.block_skill,
		"dodge_skill": profile.dodge_skill, "heavy_chance": profile.heavy_chance,
		"magic_chance": profile.magic_chance, "reaction_time": profile.reaction_time,
		"telegraph": profile.telegraph, "preferred_range": profile.preferred_range,
	}
	_check_phase()


func update(delta: float) -> void:
	if not me.is_alive() or enemy == null or not enemy.is_alive():
		me.move_input = Vector2.ZERO
		me.block_held = false
		return
	_check_phase()
	_decision_timer -= delta
	_block_timer -= delta
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = rng.randf_range(1.2, 2.6)
		_strafe = -_strafe if rng.randf() < 0.5 else _strafe
	me.block_held = _block_timer > 0.0 and me.stamina_ratio() > 0.15
	_react(delta)
	_move()
	if _decision_timer <= 0.0:
		_decision_timer = DECISION_SECONDS
		_decide()


## Phase changes at health thresholds (data: [{"below": 0.7, ...overrides, "hint"}]).
func _check_phase() -> void:
	var ratio := me.health_ratio()
	var next := phase_index
	for i in profile.phases.size():
		if ratio <= float(profile.phases[i].get("below", 1.0)):
			next = i
	if next == phase_index:
		return
	phase_index = next
	var phase: Dictionary = profile.phases[next]
	for key: String in phase:
		if params.has(key):
			params[key] = phase[key]
	me.telegraph = float(params["telegraph"]) * (1.3 if Settings.get_value("combat_assist") else 1.0)
	if phase.has("hint") and battle != null and Settings.get_value("show_hints"):
		battle.hint.emit(phase["hint"])


func _distance() -> float:
	return (enemy.planar_position() - me.planar_position()).length()


## Reacting to incoming attacks after a human-like delay.
func _react(_delta: float) -> void:
	var threatened := (enemy.is_winding_up() and _distance() < enemy.stats.attack_range + 1.6) \
			or battle.projectiles_toward(me, 5.0) > 0
	if not threatened:
		_threat_seen = false
		return
	if not _threat_seen:
		_threat_seen = true
		_react_at = battle.time + float(params["reaction_time"]) * rng.randf_range(0.8, 1.25)
		var roll := rng.randf()
		if roll < float(params["dodge_skill"]):
			_reaction = "dodge"
		elif roll < float(params["dodge_skill"]) + float(params["block_skill"]):
			_reaction = "block"
		else:
			_reaction = ""
	if battle.time < _react_at or _reaction.is_empty():
		return
	if _reaction == "dodge" and me.stamina >= me.stats.dodge_stamina:
		var side := me.forward().cross(Vector3.UP) * _strafe
		me.move_input = Vector2(side.x - me.forward().x * 0.4, side.z - me.forward().z * 0.4)
		me.request("dodge")
	elif _reaction == "block":
		_block_timer = 0.7
	_reaction = ""


func _move() -> void:
	if me.state != Combatant.State.FREE and me.state != Combatant.State.BLOCK:
		return
	var to := enemy.planar_position() - me.planar_position()
	var distance := to.length()
	var direction := to.normalized()
	var preferred: float = params["preferred_range"]
	var low_stamina := me.stamina_ratio() < 0.25 or me.is_exhausted()
	_retreating = low_stamina and distance < preferred + 2.5
	var move := Vector3.ZERO
	if _retreating:
		move = -direction * 0.8
	elif distance > preferred + 0.35:
		move = direction
	elif distance < preferred - 0.6:
		move = -direction * 0.6
	var side := direction.cross(Vector3.UP) * _strafe * 0.45
	move += side
	me.move_input = Vector2(move.x, move.z).limit_length(1.0)
	me.sprint = distance > preferred + 4.0 and me.stamina_ratio() > 0.6


func _decide() -> void:
	if me.state != Combatant.State.FREE and me.state != Combatant.State.BLOCK:
		# Mid-combo: maybe continue the chain.
		if me.state == Combatant.State.ATTACK and me.phase == "recovery" \
				and rng.randf() < float(params["aggression"]) * 0.6:
			me.request("attack")
		return
	if _retreating:
		return
	var distance := _distance()
	var in_range := distance <= me.stats.attack_range + Combatant.RADIUS * 0.8
	# Guarding opponents hold their block when the player is close.
	if distance < 3.0 and _block_timer <= 0.0 and rng.randf() < float(params["block_skill"]) * 0.35 \
			and not enemy.is_recovering():
		_block_timer = rng.randf_range(0.8, 1.6)
		return
	if me.magic_ready() and distance > 2.5 and distance < me.ability.cast_range \
			and me.stamina >= me.ability.stamina_cost and rng.randf() < float(params["magic_chance"]):
		me.request("magic")
		return
	if not in_range:
		return
	# Punish openings eagerly; otherwise attack by temperament.
	var chance := float(params["aggression"]) * (1.8 if enemy.is_recovering() else 0.75)
	if rng.randf() < chance:
		_block_timer = 0.0
		me.block_held = false
		me.request("heavy" if rng.randf() < float(params["heavy_chance"]) else "attack")
