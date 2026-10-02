class_name BattleOutcome
extends RefCounted
## What happened in a simulated battle, summed up from its log: who won and
## how, and a tally for every combatant. The result screen reads it and
## experience tracking learns from it.

## Tally keys, in the order the result screen lists them.
const TALLIES: Array[String] = [
	"damage_dealt", "damage_taken", "hits_landed", "heavy_hits", "blows_blocked_by_foe", "blows_evaded_by_foe",
	"whiffs", "dodges", "perfect_dodges", "blocks", "parries", "staggers_caused", "knockdowns_caused",
	"flinches_caused", "interruptions_caused", "guard_breaks_caused", "openings_punished", "flank_hits",
	"casts", "techniques", "exhaustions", "staggered", "knocked_down", "max_combo",
]

var winner_team := -1
## "knockout", "decision" or "draw".
var reason := ""
var duration := 0.0
## Per combatant index: the tallies above plus "id", "name", "team",
## "health_left", "health_ratio", "lowest_health_ratio", "knocked_out".
var fighters: Array[Dictionary] = []


static func from(state: BattleState, battle_log: BattleLog) -> BattleOutcome:
	var outcome := BattleOutcome.new()
	outcome.winner_team = state.winner_team
	outcome.duration = state.time
	var end := battle_log.events_of("battle_end")
	outcome.reason = end[-1].get("reason", "knockout") if not end.is_empty() else ""
	if outcome.winner_team < 0 and state.finished:
		outcome.reason = "draw"
	for fighter in state.combatants:
		var tally := {"id": fighter.spec.id, "name": fighter.spec.display_name, "team": fighter.team,
				"health_left": fighter.health, "health_ratio": fighter.health_ratio(), "lowest_health_ratio": 1.0,
				"knocked_out": not fighter.is_alive()}
		for key: String in TALLIES:
			tally[key] = 0.0 if key.begins_with("damage") else 0
		outcome.fighters.append(tally)
	for event in battle_log.events:
		outcome._count(state, event)
	return outcome


func _count(state: BattleState, event: Dictionary) -> void:
	var actor: int = event.get("actor", -1)
	var target: int = event.get("target", -1)
	match event["type"]:
		"damage":
			if target >= 0:
				var victim := fighters[target]
				victim["damage_taken"] += float(event["amount"])
				var ratio := float(event["health_left"]) / maxf(state.combatants[target].max_health, 1.0)
				victim["lowest_health_ratio"] = minf(victim["lowest_health_ratio"], ratio)
			if actor >= 0:
				var dealer := fighters[actor]
				dealer["damage_dealt"] += float(event["amount"])
				if event["kind"] != "burn" and event["outcome"] == "hit":
					dealer["hits_landed"] += 1
					if event["kind"] == "heavy":
						dealer["heavy_hits"] += 1
					if event.get("opening", false):
						dealer["openings_punished"] += 1
		"hit":
			if event.get("flank", false) and event.get("outcome", "") == "hit":
				fighters[actor]["flank_hits"] += 1
		"evade":
			fighters[actor]["dodges"] += 1
			if event.get("perfect", false):
				fighters[actor]["perfect_dodges"] += 1
			if target >= 0:
				fighters[target]["blows_evaded_by_foe"] += 1
		"block":
			fighters[actor]["blocks"] += 1
			if target >= 0:
				fighters[target]["blows_blocked_by_foe"] += 1
		"parry":
			fighters[actor]["parries"] += 1
			if target >= 0:
				fighters[target]["blows_blocked_by_foe"] += 1
		"staggered":
			fighters[actor]["staggered"] += 1
			if target >= 0:
				fighters[target]["staggers_caused"] += 1
		"knockdown":
			fighters[actor]["knocked_down"] += 1
			if target >= 0:
				fighters[target]["knockdowns_caused"] += 1
		"flinch":
			if target >= 0:
				fighters[target]["flinches_caused"] += 1
		"interrupted":
			if target >= 0:
				fighters[target]["interruptions_caused"] += 1
		"guard_break":
			if target >= 0:
				fighters[target]["guard_breaks_caused"] += 1
		"whiff":
			fighters[actor]["whiffs"] += 1
		"cast_release":
			fighters[actor]["casts"] += 1
		"technique":
			fighters[actor]["techniques"] += 1
		"exhausted":
			fighters[actor]["exhaustions"] += 1
		"strike":
			fighters[actor]["max_combo"] = maxi(fighters[actor]["max_combo"], int(event.get("combo", 0)))


func player_won() -> bool:
	return winner_team == BattleState.PLAYER_TEAM


## The tally of the first combatant on a team.
func side(team_index: int) -> Dictionary:
	for tally in fighters:
		if tally["team"] == team_index:
			return tally
	return {}


func to_dict() -> Dictionary:
	return {"winner_team": winner_team, "reason": reason, "duration": snappedf(duration, 0.01),
			"fighters": fighters.duplicate(true)}
