class_name BattleLog
extends RefCounted
## The record of a simulated battle: who took part, every event in order and
## a snapshot of the full state every few ticks. The 3D replay plays this
## back; results and experience are read from it. It holds plain data only.

var tick_rate := 30
## The setup: arena, seed and each combatant's inputs.
var header: Dictionary = {}
var events: Array[Dictionary] = []
## Full BattleState snapshots, oldest first; the first is the starting state.
var keyframes: Array[Dictionary] = []
var final: Dictionary = {}


static func begin(state: BattleState, rate: int) -> BattleLog:
	var result := BattleLog.new()
	result.tick_rate = rate
	var specs: Array = []
	var teams: Array = []
	for fighter in state.combatants:
		specs.append(fighter.spec.to_dict())
		teams.append(fighter.team)
	result.header = {"trial": state.trial_id, "arena": state.layout.id, "seed": state.battle_seed,
			"combatants": specs, "teams": teams}
	result.keyframes.append(state.snapshot())
	return result


func record(frame: SimFrame) -> void:
	events.append_array(frame.events)


func keyframe(state: BattleState) -> void:
	keyframes.append(state.snapshot())


func finish(state: BattleState) -> void:
	final = state.snapshot()
	if keyframes.is_empty() or keyframes[-1]["tick"] != final["tick"]:
		keyframes.append(final)


func duration() -> float:
	return float(final.get("time", 0.0))


func events_of(type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if event["type"] == type:
			result.append(event)
	return result


func to_dict() -> Dictionary:
	return {"tick_rate": tick_rate, "header": header, "events": events, "keyframes": keyframes, "final": final}
