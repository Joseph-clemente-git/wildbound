class_name BattleSession
extends RefCounted
## One fight from start to finish: the simulation is run in full, its result
## is applied to the lodge at once (rewards, knockout, records), and the log
## is kept for the 3D replay. Watching, skipping or leaving the replay can
## never change what happened.

var trial: TrialData
var champion_uid := ""
var state: BattleState
var battle_log: BattleLog
var outcome: BattleOutcome
## What TrialSystem applied (coins, XP, story, knockout...).
var result: Dictionary = {}


## Simulates `champion` against the fight's opponent and applies the result.
## Entry (energy) must already have been paid with TrialSystem.enter.
static func start(fight: TrialData, champion: Champion, seed_value: int = 0) -> BattleSession:
	var session := BattleSession.new()
	session.trial = fight
	session.champion_uid = champion.uid
	var sim := BattleSimulator.create(BattleState.for_fight(fight, champion, seed_value))
	session.battle_log = sim.run()
	session.state = sim.state
	session.outcome = sim.outcome()
	session.result = TrialSystem.apply_result(session.trial_outcome())
	return session


## The battle summarised for TrialSystem and the result screen.
func trial_outcome() -> Dictionary:
	var me := outcome.side(BattleState.PLAYER_TEAM)
	return {
		"trial_id": trial.id, "opponent_id": trial.opponent_id, "won": outcome.player_won(),
		"forfeited": false, "duration": outcome.duration, "reason": outcome.reason,
		"tallies": {
			"hits": me.get("hits_landed", 0) - me.get("heavy_hits", 0), "heavy_hits": me.get("heavy_hits", 0),
			"staggers": me.get("staggers_caused", 0) + me.get("knockdowns_caused", 0),
			"dodges": me.get("dodges", 0), "perfect_dodges": me.get("perfect_dodges", 0),
			"blocks": me.get("blocks", 0), "perfect_blocks": me.get("parries", 0),
			"exhaustions": me.get("exhaustions", 0), "spells": me.get("casts", 0),
		},
		"experience": {}, "growths": [],
		"simulation": outcome.to_dict(),
	}
