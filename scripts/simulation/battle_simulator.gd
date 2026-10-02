class_name BattleSimulator
extends RefCounted
## Runs a battle as a simulation: fixed ticks, each passing through the same
## pipeline of phases, until a knockout ends it or time runs out. The result
## is whatever the phases make happen — the simulator never picks a winner.
##
##   Combat Decision → Action Resolution → Hit / Dodge / Block → Damage
##   → Stagger / Knockback → Position Update → Stamina Update
##   → Cooldown / Recovery → Knockout → (repeat)
##
## Phases are pluggable: a stage of the pipeline that is not built yet is a
## plain SimulationPhase that does nothing.

const PIPELINE: Array[String] = [
	"decision", "action", "contact", "damage", "force", "movement", "stamina", "recovery", "knockout",
]

var state: BattleState
var phases: Array[SimulationPhase] = []
var battle_log: BattleLog
var tick_rate := 30
var tick_seconds := 1.0 / 30.0
var max_ticks := 5400
var keyframe_ticks := 6


static func create(battle: BattleState) -> BattleSimulator:
	var sim := BattleSimulator.new()
	sim.state = battle
	var config := Content.config
	sim.tick_rate = maxi(config.simulation_tick_rate, 1)
	sim.tick_seconds = 1.0 / sim.tick_rate
	sim.max_ticks = ceili(config.simulation_max_seconds * sim.tick_rate)
	sim.keyframe_ticks = maxi(config.simulation_keyframe_ticks, 1)
	for phase_name: String in PIPELINE:
		sim.phases.append(default_phase(phase_name))
	sim.battle_log = BattleLog.begin(battle, sim.tick_rate)
	return sim


## The phase used for each pipeline step until a later stage provides one.
static func default_phase(phase_name: String) -> SimulationPhase:
	match phase_name:
		"action":
			return ActionPhase.new()
		"contact":
			return ContactPhase.new()
		"movement":
			return MovementPhase.new()
		"recovery":
			return CooldownPhase.new()
		"knockout":
			return KnockoutPhase.new()
	return SimulationPhase.new(phase_name)


## Swaps in the phase for a pipeline step (by its name).
func use_phase(phase: SimulationPhase) -> void:
	for i in phases.size():
		if phases[i].name == phase.name:
			phases[i] = phase
			return
	push_error("BattleSimulator: no pipeline step named '%s'" % phase.name)


## Advances one tick. Returns that tick's frame, or null once finished.
func step() -> SimFrame:
	if state.finished:
		return null
	# Time is derived from the tick count so it never drifts.
	var frame := SimFrame.new(state.tick + 1, (state.tick + 1) * tick_seconds, tick_seconds)
	for phase in phases:
		phase.run(state, frame)
	state.tick = frame.tick
	state.time = frame.time
	if not state.finished and state.tick >= max_ticks:
		state.finished = true
		state.winner_team = -1
		frame.emit("battle_end", -1, -1, {"winner_team": -1, "reason": "time"})
	battle_log.record(frame)
	if state.finished:
		battle_log.finish(state)
	elif state.tick % keyframe_ticks == 0:
		battle_log.keyframe(state)
	return frame


## Runs the whole battle headless and returns its log.
func run() -> BattleLog:
	while not state.finished:
		step()
	return battle_log
