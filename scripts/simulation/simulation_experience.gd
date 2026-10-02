class_name SimulationExperience
extends RefCounted
## Turns a simulated battle into what the champion learned (mechanics §10-23).
##
## Every meaningful action the champion performed is read from the battle log
## and reported to an ExperienceSession, which weighs it by difficulty,
## repetition and remaining potential and caps it per battle:
##
##   successful attack → Offensive (and weapon familiarity)
##   combo / opening   → Attack-Speed, Offensive
##   heavy blow        → Strength;  stagger / guard break caused → Strength
##   dodge             → Evasion;   block / parry → Defense
##   flank / reposition→ Agility
##   steady effort without running dry → Endurance; a long fight → Endurance
##   surviving heavy damage or near-defeat → Resilience
##   weapon use → weapon familiarity;  Aether Arts → magic familiarity
##
## Fighting in deep water teaches Swimming and fighting aloft teaches Flight
## (Natural Foundation), whatever the animal.
##
## Defeat teaches too — but only from real effort, never as a farm: a defeat
## in which the champion barely fought teaches little, and each loss in a row
## teaches less than the one before. Nothing here grants stat points directly;
## experience turns into growth only through GrowthSystem thresholds.

const STAMINA_WINDOW := 12.0
const HEAVY_DAMAGE_RATIO := 0.12
const LOW_HEALTH_RATIO := 0.25
const LOW_HEALTH_SURVIVE_SECONDS := 3.0
## Two landed blows this close together count as a combo.
const COMBO_GAP := 1.2
## Natural Foundation progress per second of terrain use, and its cap per battle.
const TERRAIN_PROGRESS_PER_SECOND := 0.5
const TERRAIN_PROGRESS_CAP := 12.0


## Banks the experience of `champion` (combatant `index` of the battle) and
## resolves growth. Returns {"gains", "growths", "difficulty_ratio",
## "difficulty_multiplier", "defeat_factor"}.
static func collect(champion: Champion, opponent: OpponentData, battle_log: BattleLog,
		outcome: BattleOutcome, index: int = 0) -> Dictionary:
	var session := ExperienceSession.new(champion, PowerRating.for_opponent(opponent))
	var max_health := _max_health(battle_log, index)
	var last_blow := -INF
	var window_start := 0.0
	var window_actions := 0
	var window_exhausted := false
	var low_health_at := -1.0
	var survived_low := false
	var knocked_out_at := INF
	for event in battle_log.events:
		if event["type"] == "knockout" and event["actor"] == index:
			knocked_out_at = float(event["time"])
	for event in battle_log.events:
		var time := float(event["time"])
		while time - window_start >= STAMINA_WINDOW:
			if window_actions >= 3 and not window_exhausted:
				session.report("stamina_discipline", window_start + STAMINA_WINDOW)
			window_start += STAMINA_WINDOW
			window_actions = 0
			window_exhausted = false
		if low_health_at >= 0.0 and not survived_low and time - low_health_at >= LOW_HEALTH_SURVIVE_SECONDS \
				and knocked_out_at > low_health_at + LOW_HEALTH_SURVIVE_SECONDS:
			survived_low = true
			session.report("survived_low_health", time)
		var actor: int = event.get("actor", -1)
		var target: int = event.get("target", -1)
		match event["type"]:
			"action_start":
				if actor == index and event["action"] in ["attack", "heavy", "dodge", "cast"]:
					window_actions += 1
			"damage":
				if actor == index and event.get("kind", "") != "burn" and event.get("outcome", "") == "hit":
					_report_blow(session, event, time)
					if event.get("kind", "") == "light" and time - last_blow <= COMBO_GAP:
						session.report("combo_hit", time)
					last_blow = time
				if target == index:
					var amount := float(event["amount"])
					if amount >= max_health * HEAVY_DAMAGE_RATIO and float(event["health_left"]) > 0.0:
						session.report("heavy_damage_survived", time)
					if low_health_at < 0.0 and float(event["health_left"]) > 0.0 \
							and float(event["health_left"]) <= max_health * LOW_HEALTH_RATIO:
						low_health_at = time
			"hit":
				if actor == index and event.get("flank", false) and event.get("outcome", "") == "hit":
					session.report("reposition", time)
			"staggered", "knockdown":
				if target == index and event.get("reason", "") != "flinch":
					session.report("stagger_caused", time)
			"guard_break":
				if target == index:
					session.report("guard_break", time)
			"technique":
				if actor == index:
					session.report("technique", time, str(event.get("technique", "")))
			"cast_release":
				if actor == index:
					session.report("magic_cast", time, str(event.get("ability", "")))
			"evade":
				if actor == index:
					session.report("perfect_dodge" if event.get("perfect", false) else "dodge", time)
					if event.get("kind", "") == "heavy":
						session.report("dodge_heavy", time)
					elif event.get("kind", "") == "cast":
						session.report("dodge_magic", time)
			"block":
				if actor == index:
					session.report("block", time)
					if event.get("kind", "") == "heavy":
						session.report("block_heavy", time)
			"parry":
				if actor == index:
					session.report("perfect_block", time)
			"exhausted":
				if actor == index:
					window_exhausted = true
	var won: bool = outcome.winner_team == int(outcome.fighters[index]["team"])
	if outcome.duration > 60.0:
		session.report("long_battle", outcome.duration)
	var foe := outcome.side(1 - int(outcome.fighters[index]["team"]))
	var dealt_ratio := 1.0 - float(foe.get("health_ratio", 1.0))
	if not won and outcome.duration > 50.0 and dealt_ratio >= 0.4:
		session.report("prolonged_defeat", outcome.duration)
	var defeat_factor := 1.0 if won else defeat_teaching(champion, dealt_ratio)
	if defeat_factor < 1.0:
		for track: String in session.gains.keys():
			session.gains[track] = float(session.gains[track]) * defeat_factor
	var result := session.commit()
	var growths: Array = result["growths"]
	growths.append_array(_terrain_growth(champion, battle_log, index))
	return {"gains": result["gains"], "growths": growths, "difficulty_ratio": session.difficulty_ratio,
			"difficulty_multiplier": session.difficulty_multiplier, "defeat_factor": defeat_factor}


## Share of a defeat's experience kept: real effort teaches, losing on
## purpose does not. Fades with every loss in a row.
static func defeat_teaching(champion: Champion, dealt_ratio: float) -> float:
	var effort := clampf(dealt_ratio / 0.4, 0.15, 1.0)
	var streak := 1.0 / (1.0 + maxf(champion.loss_streak, 0) * 0.5)
	return effort * streak


static func _report_blow(session: ExperienceSession, event: Dictionary, time: float) -> void:
	var kind: String = event.get("kind", "light")
	match kind:
		"cast":
			session.report("magic_hit", time, str(event.get("ability", "")))
		"heavy":
			session.report("heavy_hit", time)
		_:
			session.report("hit", time)
	if event.get("opening", false):
		session.report("punish", time, kind)


## Swimming from time in deep water, Flight from time aloft — any animal.
static func _terrain_growth(champion: Champion, battle_log: BattleLog, index: int) -> Array[Dictionary]:
	var wet := 0.0
	var aloft := 0.0
	var water: Array = []
	var arena := Content.arena(battle_log.header.get("arena", ""))
	if arena != null:
		water = arena.water_zones
	var step := 1.0 / float(maxi(battle_log.tick_rate, 1)) * float(Content.config.simulation_keyframe_ticks)
	for frame: Dictionary in battle_log.keyframes:
		var me: Dictionary = frame["combatants"][index]
		var at := Vector2(float(me["position"][0]), float(me["position"][1]))
		if float(me["elevation"]) > 0.5:
			aloft += step
		else:
			for zone: Vector3 in water:
				if at.distance_to(Vector2(zone.x, zone.y)) <= zone.z:
					wet += step
					break
	var events: Array[Dictionary] = []
	for pair in [["skill:swimming", wet], ["skill:flight", aloft]]:
		var amount := minf(float(pair[1]) * TERRAIN_PROGRESS_PER_SECOND, TERRAIN_PROGRESS_CAP)
		if amount < 1.0:
			continue
		var target: String = pair[0]
		var cap := Content.config.natural_rank_cap
		if champion.skills.get_rank(target) >= cap and champion.skills.progress_ratio(target) >= 0.99:
			continue
		if not champion.skills.is_learned(target):
			champion.skills.set_rank(target, GameEnums.Rank.FOUNDATION)
		var reached := champion.skills.add_progress(target, amount, cap)
		events.append({"track": "natural", "target": target, "amount": amount,
				"rank": reached.back() if not reached.is_empty() else -1,
				"text": "%s improved%s" % [SkillCatalog.target_name(target),
						(" to " + GameEnums.rank_name(reached.back())) if not reached.is_empty() else ""]})
	return events


static func _max_health(battle_log: BattleLog, index: int) -> float:
	return maxf(float(battle_log.keyframes[0]["combatants"][index]["max_health"]), 1.0)
