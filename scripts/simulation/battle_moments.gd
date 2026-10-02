class_name BattleMoments
extends RefCounted
## The few moments worth telling from a battle, picked from its log and
## told from the Keeper's side (team 0). Plain sentences for the result
## screen — what happened, in the order it mattered.

const MAX_MOMENTS := 5


static func tell(battle_log: BattleLog, outcome: BattleOutcome) -> PackedStringArray:
	var names: Array = battle_log.header["combatants"].map(func(spec: Dictionary) -> String: return spec.get("name", "?"))
	var lines := PackedStringArray()
	var biggest := {}
	var first_down := {}
	var parries := 0
	var techniques := {}
	var guard_breaks := 0
	for event in battle_log.events:
		match event["type"]:
			"damage":
				if event.get("kind", "") != "burn" and (biggest.is_empty() or float(event["amount"]) > float(biggest["amount"])):
					biggest = event

			"knockdown":
				if first_down.is_empty():
					first_down = event
			"parry":
				if outcome.fighters[event["actor"]]["team"] == 0:
					parries += 1
			"technique":
				if outcome.fighters[event["actor"]]["team"] == 0:
					techniques[event["technique"]] = int(techniques.get(event["technique"], 0)) + 1
			"guard_break":
				if event.get("target", -1) >= 0 and outcome.fighters[event["target"]]["team"] == 0:
					guard_breaks += 1
	if not first_down.is_empty():
		lines.append("%s was floored at %s." % [names[first_down["actor"]], _clock(first_down["time"])])
	if not biggest.is_empty() and biggest["actor"] >= 0:
		lines.append("Biggest blow: %s's %s for %d%s." % [names[biggest["actor"]], _kind(biggest["kind"]),
				roundi(float(biggest["amount"])), " into an opening" if biggest.get("opening", false) else ""])
	if parries > 0:
		lines.append("%s parried %d blow%s." % [names[0], parries, "" if parries == 1 else "s"])
	for technique_id: String in techniques:
		var technique := Content.technique(technique_id)
		if technique != null:
			lines.append("%s used %s %d time%s." % [names[0], technique.display_name, techniques[technique_id],
					"" if techniques[technique_id] == 1 else "s"])
	if guard_breaks > 0:
		lines.append("%s's guard was broken %d time%s." % [names[0], guard_breaks, "" if guard_breaks == 1 else "s"])
	var me := outcome.side(0)
	if outcome.player_won() and float(me.get("lowest_health_ratio", 1.0)) < 0.25:
		lines.append("A comeback: %s won from below a quarter of its health." % names[0])
	if int(me.get("exhaustions", 0)) > 0:
		lines.append("%s ran out of breath %d time%s." % [names[0], me["exhaustions"], "" if me["exhaustions"] == 1 else "s"])
	while lines.size() > MAX_MOMENTS:
		lines.remove_at(lines.size() - 1)
	return lines


## "by knockout at 0:34", "on decision after 3:00", "a draw after 3:00".
static func how_it_ended(outcome: BattleOutcome) -> String:
	match outcome.reason:
		"knockout":
			return "by knockout at %s" % _clock(outcome.duration)
		"decision":
			return "on the judges' decision after %s" % _clock(outcome.duration)
	return "a draw after %s" % _clock(outcome.duration)


static func _clock(seconds: Variant) -> String:
	var total := roundi(float(seconds))
	return "%d:%02d" % [total / 60, total % 60]


static func _kind(kind: String) -> String:
	match kind:
		"heavy":
			return "heavy blow"
		"cast":
			return "Aether Art"
	return "strike"
