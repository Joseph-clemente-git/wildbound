class_name SimulationPhase
extends RefCounted
## One step of the per-tick pipeline. The simulator runs every phase in order
## each tick; each reads and changes the BattleState and the tick's SimFrame.
## The base class does nothing, so a stage of the pipeline that is not built
## yet simply passes the tick on.

var name := ""


func _init(phase_name: String = "") -> void:
	name = phase_name


func run(_state: BattleState, _frame: SimFrame) -> void:
	pass
