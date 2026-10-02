class_name ReplayTimeline
extends RefCounted
## Reads a BattleLog for playback: the state of every combatant at any
## moment (interpolated between keyframes), the events in any time window,
## and each combatant's actions as spans with their real durations so the
## replay plays every clip exactly as long as the simulation did.

var battle_log: BattleLog
var duration := 0.0
var keyframes: Array[Dictionary] = []
var events: Array[Dictionary] = []
## Combatant index -> [{"action", "start", "end"}], in order.
var spans: Dictionary = {}


func _init(log_data: BattleLog) -> void:
	battle_log = log_data
	keyframes.assign(log_data.keyframes)
	events.assign(log_data.events)
	duration = log_data.duration()
	_build_spans()


func combatant_count() -> int:
	return keyframes[0]["combatants"].size() if not keyframes.is_empty() else 0


## Every combatant at time `t`: {"position": Vector2, "elevation", "facing":
## Vector2, "health", "max_health", "stamina", "max_stamina", "action"}.
func sample(t: float) -> Array[Dictionary]:
	var bracket := _bracket(t)
	var a: Dictionary = keyframes[bracket[0]]
	var b: Dictionary = keyframes[bracket[1]]
	var span := float(b["time"]) - float(a["time"])
	var weight := clampf((t - float(a["time"])) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var result: Array[Dictionary] = []
	for i in a["combatants"].size():
		var from: Dictionary = a["combatants"][i]
		var to: Dictionary = b["combatants"][i]
		var facing := _vec(from["facing"]).lerp(_vec(to["facing"]), weight)
		result.append({
			"position": _vec(from["position"]).lerp(_vec(to["position"]), weight),
			"elevation": lerpf(float(from["elevation"]), float(to["elevation"]), weight),
			"facing": facing.normalized() if facing.length() > 0.001 else _vec(from["facing"]),
			"health": lerpf(float(from["health"]), float(to["health"]), weight),
			"max_health": float(from["max_health"]),
			"stamina": lerpf(float(from["stamina"]), float(to["stamina"]), weight),
			"max_stamina": float(from["max_stamina"]),
			"action": from["action"],
		})
	return result


## Shots in flight at time `t`: [{"id", "position": Vector2, "ability", "kind"}].
func projectiles(t: float) -> Array[Dictionary]:
	var bracket := _bracket(t)
	var a: Dictionary = keyframes[bracket[0]]
	var b: Dictionary = keyframes[bracket[1]]
	var span := float(b["time"]) - float(a["time"])
	var weight := clampf((t - float(a["time"])) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var later := {}
	for shot: Dictionary in b.get("projectiles", []):
		later[shot["id"]] = shot
	var result: Array[Dictionary] = []
	for shot: Dictionary in a.get("projectiles", []):
		var position := _vec(shot["position"])
		if later.has(shot["id"]):
			position = position.lerp(_vec(later[shot["id"]]["position"]), weight)
		result.append({"id": shot["id"], "position": position, "ability": shot.get("ability", ""), "kind": shot.get("kind", "")})
	return result


## Events with from < time <= to.
func events_between(from: float, to: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		var time := float(event["time"])
		if time > from and time <= to:
			result.append(event)
		elif time > to:
			break
	return result


## The action span a combatant is in at time `t` ({} when idle or moving).
func span_at(index: int, t: float) -> Dictionary:
	for span: Dictionary in spans.get(index, []):
		if t >= span["start"] and t < span["end"]:
			return span
		if span["start"] > t:
			break
	return {}


func _build_spans() -> void:
	var open := {}
	for event in events:
		var actor: int = event.get("actor", -1)
		if actor < 0:
			continue
		var time := float(event["time"])
		var name := ""
		match event["type"]:
			"action_start":
				name = event["action"]
			"staggered":
				name = "stagger"
			"flinch":
				name = "flinch"
			"knockdown":
				name = "knockdown"
			"knockout":
				name = "ko"
			"action_end":
				if open.has(actor):
					open[actor]["end"] = time
					open.erase(actor)
				continue
			_:
				continue
		if open.has(actor):
			open[actor]["end"] = time
		var span := {"action": name, "start": time, "end": duration if name == "ko" else time + float(event.get("seconds", 0.6))}
		if not spans.has(actor):
			spans[actor] = []
		spans[actor].append(span)
		open[actor] = span
		if name in ["stagger", "flinch", "knockdown"]:
			open.erase(actor)  # held states end on their own timer


func _bracket(t: float) -> Array[int]:
	var low := 0
	var high := keyframes.size() - 1
	if high <= 0 or t <= float(keyframes[0]["time"]):
		return [0, 0]
	if t >= float(keyframes[high]["time"]):
		return [high, high]
	while high - low > 1:
		var middle := (low + high) / 2
		if float(keyframes[middle]["time"]) <= t:
			low = middle
		else:
			high = middle
	return [low, high]


static func _vec(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2(float(value[0]), float(value[1]))
