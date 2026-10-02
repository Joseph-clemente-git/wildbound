class_name SimFrame
extends RefCounted
## Scratch data for one simulation tick, handed from phase to phase in
## pipeline order and then written to the battle log.

var tick := 0
var time := 0.0
var delta := 0.0
## Combat Decision output: combatant index -> intent, e.g.
## {"action": "attack", "target": 1, "move": Vector2(...)}.
var intents: Dictionary = {}
## Attacks whose active window reached someone this tick, filled by Action
## Resolution and resolved by Hit / Dodge / Block and Damage.
var contacts: Array[Dictionary] = []
## Everything that happened this tick, in order.
var events: Array[Dictionary] = []


func _init(tick_number: int, tick_time: float, tick_delta: float) -> void:
	tick = tick_number
	time = tick_time
	delta = tick_delta


## Records something that happened. `actor` and `target` are combatant
## indexes (-1 for none); `data` holds the details.
func emit(type: String, actor: int = -1, target: int = -1, data: Dictionary = {}) -> Dictionary:
	var event := {"tick": tick, "time": snappedf(time, 0.0001), "type": type, "actor": actor, "target": target}
	event.merge(data)
	events.append(event)
	return event


func events_of(type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if event["type"] == type:
			result.append(event)
	return result
