extends TestCase
## Stages 20-21 of the battle simulation: experience is read from what the
## champion actually did in the simulated battle, and terrain teaches the
## Natural Foundation skills.

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)


## A hand-written battle log: `events` from the champion's fight, `frames`
## keyframes of the champion's position and height.
func _log(events: Array, frames: Array = [], arena_id: String = "meadow_ring") -> BattleLog:
	var battle_log := BattleLog.new()
	battle_log.header = {"arena": arena_id}
	battle_log.keyframes.append(_frame(Vector2.ZERO, 0.0))
	for frame: Dictionary in frames:
		battle_log.keyframes.append(frame)
	for event: Dictionary in events:
		battle_log.events.append(event)
	return battle_log


func _frame(at: Vector2, height: float) -> Dictionary:
	return {"combatants": [
		{"position": [at.x, at.y], "elevation": height, "max_health": 100.0},
		{"position": [0.0, 5.0], "elevation": 0.0, "max_health": 100.0},
	]}


func _outcome(won: bool, foe_health_ratio: float, duration: float = 30.0) -> BattleOutcome:
	var outcome := BattleOutcome.new()
	outcome.winner_team = 0 if won else 1
	outcome.duration = duration
	outcome.fighters.append({"team": 0, "health_ratio": 1.0 if won else 0.0})
	outcome.fighters.append({"team": 1, "health_ratio": foe_health_ratio})
	return outcome


func _event(type: String, time: float, actor: int, target: int, data: Dictionary = {}) -> Dictionary:
	var event := {"type": type, "time": time, "actor": actor, "target": target}
	event.merge(data)
	return event


## A busy fight: blows, a heavy, a flank, dodges, blocks and a parry.
func _busy_fight() -> Array:
	return [
		_event("damage", 1.0, 0, 1, {"amount": 8.0, "kind": "light", "outcome": "hit", "opening": false, "health_left": 92.0}),
		_event("damage", 1.8, 0, 1, {"amount": 8.0, "kind": "light", "outcome": "hit", "opening": true, "health_left": 84.0}),
		_event("damage", 5.0, 0, 1, {"amount": 15.0, "kind": "heavy", "outcome": "hit", "opening": false, "health_left": 69.0}),
		_event("hit", 7.0, 0, 1, {"kind": "light", "outcome": "hit", "flank": true}),
		_event("staggered", 7.0, 1, 0, {"reason": "poise"}),
		_event("evade", 9.0, 0, 1, {"perfect": true, "kind": "heavy"}),
		_event("block", 11.0, 0, 1, {"perfect": false, "kind": "light"}),
		_event("parry", 13.0, 0, 1, {"kind": "light"}),
	]


func _collect(events: Array, outcome: BattleOutcome, frames: Array = [], arena_id: String = "meadow_ring") -> Dictionary:
	return SimulationExperience.collect(champion, Content.opponent("rook"), _log(events, frames, arena_id), outcome)


func test_actions_teach_their_tracks() -> void:
	var learned := _collect(_busy_fight(), _outcome(true, 0.0))
	var gains: Dictionary = learned["gains"]
	for track in ["offensive", "tempo", "strength", "agility", "evasion", "defense", "weapon:sword"]:
		check(float(gains.get(track, 0.0)) > 0.0, "%s learned (%s)" % [track, gains])
	check_eq(float(learned["defeat_factor"]), 1.0, "a victory teaches in full")


func test_only_the_champions_own_actions_count() -> void:
	# The same fight, but every action was the opponent's.
	var mirrored: Array = []
	for event: Dictionary in _busy_fight():
		var flipped := event.duplicate()
		flipped["actor"] = event["target"]
		flipped["target"] = event["actor"]
		if flipped["type"] == "damage":
			flipped["health_left"] = 99.0
		mirrored.append(flipped)
	var gains: Dictionary = _collect(mirrored, _outcome(true, 0.0))["gains"]
	for track in ["offensive", "strength", "evasion", "defense", "agility"]:
		check_eq(float(gains.get(track, 0.0)), 0.0, "the opponent's %s teaches nothing" % track)


func test_surviving_teaches_resilience() -> void:
	var events := [
		_event("damage", 2.0, 1, 0, {"amount": 30.0, "kind": "heavy", "outcome": "hit", "opening": false, "health_left": 70.0}),
		_event("damage", 6.0, 1, 0, {"amount": 50.0, "kind": "heavy", "outcome": "hit", "opening": false, "health_left": 20.0}),
		_event("damage", 12.0, 0, 1, {"amount": 5.0, "kind": "light", "outcome": "hit", "opening": false, "health_left": 1.0}),
	]
	var gains: Dictionary = _collect(events, _outcome(true, 0.0))["gains"]
	check(float(gains.get("resilience", 0.0)) > 0.0, "heavy damage and near-defeat survived")


func test_steady_effort_teaches_endurance() -> void:
	var events: Array = []
	for second in 30:
		events.append(_event("action_start", float(second), 0, 1, {"action": "attack"}))
	var gains: Dictionary = _collect(events, _outcome(true, 0.0, 70.0))["gains"]
	check(float(gains.get("endurance", 0.0)) > 0.0, "kept working without running dry")
	var tired: Array = events.duplicate()
	tired.append(_event("exhausted", 5.0, 0, -1))
	tired.append(_event("exhausted", 15.0, 0, -1))
	tired.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	before_each()
	var spent: Dictionary = _collect(tired, _outcome(true, 0.0, 40.0))["gains"]
	check(float(spent.get("endurance", 0.0)) < float(gains["endurance"]), "running dry teaches less discipline")


func test_a_token_defeat_teaches_little() -> void:
	var fought := _collect(_busy_fight(), _outcome(false, 0.4))
	before_each()
	var token := _collect(_busy_fight(), _outcome(false, 0.97))
	check(float(token["defeat_factor"]) < float(fought["defeat_factor"]), "barely fighting teaches less")
	check(float(token["defeat_factor"]) <= 0.2, "a token defeat keeps little (%s)" % token["defeat_factor"])
	check(_sum(token["gains"]) < _sum(fought["gains"]) * 0.5, "the gap shows in what was banked")


func test_losing_again_and_again_teaches_less() -> void:
	var factors: Array[float] = []
	for streak in 4:
		champion.loss_streak = streak
		factors.append(SimulationExperience.defeat_teaching(champion, 0.5))
	for i in range(1, factors.size()):
		check(factors[i] < factors[i - 1], "loss %d teaches less than loss %d" % [i + 1, i])
	champion.loss_streak = 0
	check_eq(SimulationExperience.defeat_teaching(champion, 0.6), 1.0, "a hard-fought first loss teaches in full")


func test_experience_never_grants_stats_directly() -> void:
	var before := {}
	for stat: String in GameEnums.STATS:
		before[stat] = champion.final_stat(stat)
	var learned := _collect(_busy_fight(), _outcome(true, 0.0))
	for track: String in learned["gains"]:
		check(ExperienceTracks.is_valid_track(track), "%s is an experience track" % track)
	var grown := 0
	for growth: Dictionary in learned["growths"]:
		if str(growth.get("target", "")).begins_with("stat:"):
			grown += 1
	var changed := 0
	for stat: String in before:
		if not is_equal_approx(champion.final_stat(stat), before[stat]):
			changed += 1
	check(changed <= grown, "stats only change through growth events")


func test_simulated_battles_bank_experience() -> void:
	var trial := Content.trial("stonewall_bout")
	TrialSystem.enter(champion, trial)
	var banked_before := champion.experience.get_lifetime("offensive")
	var session := BattleSession.start(trial, champion, 41)
	var result := session.result
	check(not (result["experience"] as Dictionary).is_empty(), "the fight taught something")
	check(result.has("growths"), "growth is reported")
	check(champion.experience.get_lifetime("offensive") > banked_before or not result["experience"].has("offensive"),
			"what was learned is banked")
	var me := session.outcome.side(BattleState.PLAYER_TEAM)
	if int(me["hits_landed"]) > 0:
		check(float(result["experience"].get("offensive", 0.0)) > 0.0, "landed blows teach Offensive")
	if int(me["dodges"]) > 0:
		check(float(result["experience"].get("evasion", 0.0)) > 0.0, "dodges teach Evasion")


func test_time_aloft_teaches_flight() -> void:
	var frames: Array = []
	for i in 80:
		frames.append(_frame(Vector2.ZERO, 2.0))
	var learned := _collect([], _outcome(true, 0.0), frames)
	check(champion.skills.is_learned("skill:flight"), "flight practised")
	check(champion.skills.get_rank("skill:flight") >= GameEnums.Rank.FOUNDATION)
	check(_has_growth(learned, "skill:flight"), "reported as growth")
	check(not champion.skills.is_learned("skill:swimming"), "no water, no swimming")


func test_time_in_deep_water_teaches_swimming() -> void:
	var frames: Array = []
	for i in 80:
		frames.append(_frame(Vector2(0.0, -5.5), 0.0))
	var learned := _collect([], _outcome(true, 0.0), frames, "valley_lakeshore")
	check(champion.skills.is_learned("skill:swimming"), "swimming practised by a dog")
	check(_has_growth(learned, "skill:swimming"))
	before_each()
	var dry: Array = []
	for i in 80:
		dry.append(_frame(Vector2(0.0, 6.0), 0.0))
	_collect([], _outcome(true, 0.0), dry, "valley_lakeshore")
	check(not champion.skills.is_learned("skill:swimming"), "staying on the shore teaches no swimming")


func test_terrain_practice_is_capped_per_battle() -> void:
	var frames: Array = []
	for i in 3000:
		frames.append(_frame(Vector2.ZERO, 2.0))
	var learned := _collect([], _outcome(true, 0.0), frames)
	for growth: Dictionary in learned["growths"]:
		if growth.get("target", "") == "skill:flight":
			check(float(growth["amount"]) <= SimulationExperience.TERRAIN_PROGRESS_CAP)


func _has_growth(learned: Dictionary, target: String) -> bool:
	for growth: Dictionary in learned["growths"]:
		if growth.get("target", "") == target:
			return true
	return false


func _sum(gains: Dictionary) -> float:
	var total := 0.0
	for track: String in gains:
		total += float(gains[track])
	return total
