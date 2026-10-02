class_name VictoryRules
extends RefCounted
## How a battle ends.
##
## - Knockout: when only one team has anyone standing, it wins. If the last
##   fighters on both sides fall on the same tick, it is a draw.
## - Time limit: a battle still running at the limit is settled by a
##   decision on performance — the team with clearly more health left (by
##   share of its maximum) wins, damage dealt breaks a near tie, and a fight
##   too close to call is a draw. Never by chance.

## Health-share lead needed to win on decision.
const DECISION_MARGIN := 0.03


## The winning team after a time limit, or -1 for a draw.
static func decide(state: BattleState, battle_log: BattleLog) -> int:
	var health := [0.0, 0.0]
	var dealt := [0.0, 0.0]
	for team_index in 2:
		var fighters := state.team(team_index)
		for fighter in fighters:
			health[team_index] += fighter.health_ratio() / maxf(fighters.size(), 1)
	for event in battle_log.events:
		if event["type"] == "damage" and event["actor"] >= 0:
			dealt[state.combatants[event["actor"]].team] += float(event["amount"])
	if absf(health[0] - health[1]) >= DECISION_MARGIN:
		return 0 if health[0] > health[1] else 1
	var total: float = dealt[0] + dealt[1]
	if total > 0.0 and absf(dealt[0] - dealt[1]) / total >= 0.1:
		return 0 if dealt[0] > dealt[1] else 1
	return -1
