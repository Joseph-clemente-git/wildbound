class_name CombatantState
extends RefCounted
## One combatant's live condition inside a simulated battle: where it is,
## what it is doing and what it has left. The unchanging inputs live in
## `spec`; everything here changes tick by tick.

## What the combatant is doing. Append only: values appear in replays.
enum Action { IDLE, MOVE, ATTACK, HEAVY, BLOCK, DODGE, CAST, STAGGER, KNOCKDOWN, RECOVER, KO }
## Where it is inside a timed action.
enum Phase { NONE, WINDUP, ACTIVE, RECOVERY }

const ACTION_NAMES: Array[String] = [
	"idle", "move", "attack", "heavy", "block", "dodge", "cast", "stagger", "knockdown", "recover", "ko",
]
## Body radius in metres, shared by every animal until bodies differ in data.
const BODY_RADIUS := 0.45

var spec: CombatantSpec
## Index in BattleState.combatants.
var index := 0
var team := 0
## Position on the arena floor (x, z) and height above it.
var position := Vector2.ZERO
var elevation := 0.0
## Unit vector the combatant faces on the floor.
var facing := Vector2(0, -1)
var velocity := Vector2.ZERO
## Direction of the dodge under way.
var dodge_direction := Vector2.ZERO

var health := 0.0
var max_health := 0.0
var stamina := 0.0
var max_stamina := 0.0

var action: Action = Action.IDLE
var phase: Phase = Phase.NONE
## Seconds spent in the current phase, and the phase's length.
var phase_time := 0.0
var phase_length := 0.0
## Position in the current light-attack chain.
var combo_step := 0
var target_index := -1

## Built-up stagger; staggers when it passes the spec's poise.
var stagger_meter := 0.0
var exhausted_time := 0.0
## Seconds left on cooldowns by key ("magic", technique ids...).
var cooldowns: Dictionary = {}
## Lasting effects, e.g. {"kind": "burn", "dps": 4.0, "time": 3.0, "source": 1}.
var effects: Array[Dictionary] = []


static func create(combatant_spec: CombatantSpec, team_index: int) -> CombatantState:
	var state := CombatantState.new()
	state.spec = combatant_spec
	state.team = team_index
	state.max_health = combatant_spec.derived.max_health
	state.max_stamina = combatant_spec.derived.max_stamina
	state.health = state.max_health
	state.stamina = state.max_stamina
	return state


func is_alive() -> bool:
	return action != Action.KO and health > 0.0


func health_ratio() -> float:
	return health / max_health if max_health > 0.0 else 0.0


func stamina_ratio() -> float:
	return stamina / max_stamina if max_stamina > 0.0 else 0.0


func is_exhausted() -> bool:
	return exhausted_time > 0.0


func cooldown(key: String) -> float:
	return float(cooldowns.get(key, 0.0))


## Plain data for replays and determinism checks. Floats are rounded so a
## snapshot compares cleanly across runs.
func to_dict() -> Dictionary:
	return {
		"index": index, "id": spec.id, "team": team,
		"position": [snappedf(position.x, 0.001), snappedf(position.y, 0.001)],
		"elevation": snappedf(elevation, 0.001),
		"facing": [snappedf(facing.x, 0.001), snappedf(facing.y, 0.001)],
		"health": snappedf(health, 0.01), "max_health": snappedf(max_health, 0.01),
		"stamina": snappedf(stamina, 0.01), "max_stamina": snappedf(max_stamina, 0.01),
		"action": ACTION_NAMES[action], "phase": phase, "phase_time": snappedf(phase_time, 0.001),
		"combo_step": combo_step, "target": target_index,
		"stagger": snappedf(stagger_meter, 0.01), "exhausted": snappedf(exhausted_time, 0.001),
		"cooldowns": cooldowns.duplicate(), "effects": effects.duplicate(true),
	}
