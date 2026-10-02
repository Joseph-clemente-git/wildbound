class_name ActionPhase
extends SimulationPhase
## Action Resolution: turns each combatant's intent into a committed, timed
## action and advances the actions already under way.
##
## Intents come from the decision step as
##   {"action": "attack" | "heavy" | "block" | "dodge" | "cast" | "",
##    "move": Vector2 (desired direction, length 0..1),
##    "dodge_dir": Vector2 (optional)}
##
## Every timed action runs WINDUP → ACTIVE → RECOVERY, with lengths from the
## combatant's derived numbers — weapon speed, Attack Speed and weapon
## mastery shape attacks; Evasion and dodge skill shape dodges; the Art's
## cast time shapes casts. Once committed, an action plays out: that
## commitment is what makes timing, openings and punishment possible.
##
## On every tick of an attack's ACTIVE window a contact is handed to the
## Hit / Dodge / Block step (which lets each swing strike each target once);
## when a cast releases, so is the Art. A swing that struck no one is a whiff.

const A := CombatantState.Action
const P := CombatantState.Phase

## Actions other steps put a combatant into (stagger, knockdown...) and that
## simply run out their RECOVERY timer here.
const HELD_STATES := [A.STAGGER, A.KNOCKDOWN, A.RECOVER]


func _init() -> void:
	super("action")


func run(state: BattleState, frame: SimFrame) -> void:
	for fighter in state.combatants:
		if not fighter.is_alive():
			continue
		var intent: Dictionary = frame.intents.get(fighter.index, {})
		_advance(fighter, intent, frame)
		_start(state, fighter, intent, frame)
		# A swing can connect on every tick of its active window.
		if fighter.action in [A.ATTACK, A.HEAVY] and fighter.phase == P.ACTIVE and not _contacted(frame, fighter):
			_add_contact(fighter, frame, false)


## Phase lengths [windup, active, recovery] for an action.
static func timings(fighter: CombatantState, action: CombatantState.Action) -> Array[float]:
	var d := fighter.spec.derived
	match action:
		A.ATTACK:
			return [d.windup, d.active, d.recovery]
		A.HEAVY:
			return [d.heavy_windup, d.active * 1.2, d.heavy_recovery]
		A.DODGE:
			return [0.0, d.dodge_iframes, d.dodge_recovery]
		A.CAST:
			var ability := fighter.spec.ability
			if ability == null:
				return [0.0, 0.0, 0.0]
			return [ability.cast_time * d.magic_cast_factor, 0.0, ability.recovery]
		A.BLOCK:
			return [Content.config.simulation_block_raise_seconds, INF, 0.0]
	return [0.0, 0.0, 0.0]


## Whether the combatant is free to begin something new.
static func is_free(fighter: CombatantState) -> bool:
	return fighter.action in [A.IDLE, A.MOVE, A.BLOCK]


static func is_committed(fighter: CombatantState) -> bool:
	return fighter.action in [A.ATTACK, A.HEAVY, A.DODGE, A.CAST] or fighter.action in HELD_STATES


func _start(state: BattleState, fighter: CombatantState, intent: Dictionary, frame: SimFrame) -> void:
	var wanted: String = intent.get("action", "")
	# Light attacks chain: a new swing may start during the previous one's recovery.
	if wanted == "attack" and fighter.action == A.ATTACK and fighter.phase == P.RECOVERY and not fighter.is_exhausted() \
			and fighter.combo_step < fighter.spec.derived.combo_max:
		_begin(fighter, A.ATTACK, frame, fighter.combo_step + 1)
		return
	# Out of breath: nothing but moving until the exhaustion passes.
	if fighter.is_exhausted() and wanted in ["attack", "heavy", "dodge", "cast", "block"]:
		wanted = ""
	if fighter.action == A.BLOCK and wanted != "block":
		fighter.action = A.IDLE
		fighter.phase = P.NONE
		frame.emit("block_down", fighter.index)
	if not is_free(fighter):
		return
	match wanted:
		"attack":
			_begin(fighter, A.ATTACK, frame, 1)
		"heavy":
			_begin(fighter, A.HEAVY, frame, 0)
		"block":
			if fighter.action != A.BLOCK:
				_begin(fighter, A.BLOCK, frame, 0)
		"dodge":
			var direction: Vector2 = intent.get("dodge_dir", Vector2.ZERO)
			if direction.length() < 0.1:
				direction = _default_dodge(state, fighter)
			fighter.dodge_direction = direction.normalized()
			_begin(fighter, A.DODGE, frame, 0, {"direction": [snappedf(direction.normalized().x, 0.001),
					snappedf(direction.normalized().y, 0.001)]})
		"cast":
			if fighter.spec.ability != null and fighter.cooldown("magic") <= 0.0:
				_begin(fighter, A.CAST, frame, 0, {"ability": fighter.spec.ability.id})


func _begin(fighter: CombatantState, action: CombatantState.Action, frame: SimFrame, combo: int,
		data: Dictionary = {}) -> void:
	fighter.action = action
	fighter.combo_step = combo
	fighter.swing += 1
	fighter.struck.clear()
	var lengths := timings(fighter, action)
	_enter(fighter, P.WINDUP, lengths[0])
	var details := {"action": CombatantState.ACTION_NAMES[action], "combo": combo}
	details.merge(data)
	frame.emit("action_start", fighter.index, fighter.target_index, details)
	# Zero-length wind-ups (dodges) take effect at once.
	_settle(fighter, frame, 0.0)


func _enter(fighter: CombatantState, phase: CombatantState.Phase, length: float) -> void:
	fighter.phase = phase
	fighter.phase_time = 0.0
	fighter.phase_length = length


func _advance(fighter: CombatantState, _intent: Dictionary, frame: SimFrame) -> void:
	if fighter.phase == P.NONE:
		return
	_settle(fighter, frame, frame.delta)


## Moves time forward inside the current action, passing through as many
## phase boundaries as `delta` covers.
func _settle(fighter: CombatantState, frame: SimFrame, delta: float) -> void:
	fighter.phase_time += delta
	while fighter.phase != P.NONE and fighter.phase_time >= fighter.phase_length:
		var spare := fighter.phase_time - fighter.phase_length
		var lengths := timings(fighter, fighter.action)
		match fighter.phase:
			P.WINDUP:
				_enter(fighter, P.ACTIVE, lengths[1])
				_on_active(fighter, frame)
			P.ACTIVE:
				_enter(fighter, P.RECOVERY, lengths[2])
				if fighter.action in [A.ATTACK, A.HEAVY] and fighter.struck.is_empty():
					frame.emit("whiff", fighter.index, fighter.target_index,
							{"kind": "heavy" if fighter.action == A.HEAVY else "light"})
			P.RECOVERY:
				_finish(fighter, frame)
				return
		fighter.phase_time = spare


func _on_active(fighter: CombatantState, frame: SimFrame) -> void:
	match fighter.action:
		A.ATTACK, A.HEAVY:
			_add_contact(fighter, frame, true)
			frame.emit("strike", fighter.index, fighter.target_index,
					{"kind": "heavy" if fighter.action == A.HEAVY else "light", "combo": fighter.combo_step})
		A.CAST:
			var ability := fighter.spec.ability
			fighter.cooldowns["magic"] = ability.cooldown
			frame.contacts.append({"attacker": fighter.index, "kind": "cast", "ability": ability.id,
					"target": fighter.target_index, "swing": fighter.swing, "first": true})
			frame.emit("cast_release", fighter.index, fighter.target_index, {"ability": ability.id})
		A.BLOCK:
			frame.emit("block_up", fighter.index)
		A.DODGE:
			frame.emit("dodge", fighter.index)


## `first` marks the tick the active window opens (a ranged weapon looses
## its shot then).
func _add_contact(fighter: CombatantState, frame: SimFrame, first: bool) -> void:
	frame.contacts.append({"attacker": fighter.index, "kind": "heavy" if fighter.action == A.HEAVY else "light",
			"combo": fighter.combo_step, "target": fighter.target_index, "swing": fighter.swing, "first": first})


static func _contacted(frame: SimFrame, fighter: CombatantState) -> bool:
	for contact in frame.contacts:
		if contact["attacker"] == fighter.index:
			return true
	return false


func _finish(fighter: CombatantState, frame: SimFrame) -> void:
	var ended := fighter.action
	fighter.action = A.IDLE
	fighter.phase = P.NONE
	fighter.phase_time = 0.0
	fighter.combo_step = 0
	frame.emit("action_end", fighter.index, -1, {"action": CombatantState.ACTION_NAMES[ended]})


## Sidestep: perpendicular to the line toward the target.
static func _default_dodge(state: BattleState, fighter: CombatantState) -> Vector2:
	var target := state.target_of(fighter)
	var toward := (target.position - fighter.position).normalized() if target != null else fighter.facing
	return Vector2(-toward.y, toward.x)
