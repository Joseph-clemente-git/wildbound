class_name BattleRecord
extends RefCounted
## Saved battles (Stage 24). A battle is kept as its inputs — every
## combatant's frozen spec, the arena and the seed — not as its frames: the
## simulation is deterministic, so running it again replays the same fight
## tick for tick. The most recent REPLAY_LIMIT battles of each champion keep
## their replay; older entries keep only the summary.

const REPLAY_LIMIT := 3


## Save-safe replay data from a battle's log header (colours as html).
static func pack(battle_log: BattleLog) -> Dictionary:
	var header: Dictionary = battle_log.header.duplicate(true)
	for spec: Dictionary in header.get("combatants", []):
		var palette: Dictionary = spec.get("palette", {})
		for key: String in palette:
			if palette[key] is Color:
				palette[key] = (palette[key] as Color).to_html()
	# Stored exactly as a save will load it back (numbers become floats).
	return JSON.parse_string(JSON.stringify(header))


## True when `entry` (a champion history entry) can be watched again.
static func has_replay(entry: Dictionary) -> bool:
	var replay: Dictionary = entry.get("replay", {})
	return not replay.is_empty() and Content.arena(str(replay.get("arena", ""))) != null \
			and (replay.get("combatants", []) as Array).size() >= 2


## Runs a saved battle again. Returns null when the record cannot be replayed.
static func rewatch(entry: Dictionary) -> BattleSession:
	if not has_replay(entry):
		return null
	var replay: Dictionary = entry["replay"]
	var players: Array[CombatantSpec] = []
	var opponents: Array[CombatantSpec] = []
	var combatants: Array = replay["combatants"]
	var teams: Array = replay.get("teams", [])
	for i in combatants.size():
		var spec := CombatantSpec.from_dict(combatants[i])
		var team := int(teams[i]) if i < teams.size() else (0 if i == 0 else 1)
		if team == BattleState.PLAYER_TEAM:
			players.append(spec)
		else:
			opponents.append(spec)
	var state := BattleState.create(Content.arena(str(replay["arena"])), players, opponents,
			int(replay.get("seed", 0)), str(replay.get("trial", "")))
	return BattleSession.watch(state, Content.trial(str(replay.get("trial", ""))))
