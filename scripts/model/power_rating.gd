class_name PowerRating
extends RefCounted
## Comparable strength estimate for difficulty-weighted experience (mechanics §22).


static func from_stats(stats: Dictionary, capability_score: float, level: int) -> float:
	var total := 0.0
	for stat: String in GameEnums.STATS:
		total += float(stats.get(stat, 30.0))
	var average := total / GameEnums.STATS.size()
	return average * (1.0 + capability_score * 0.08) + level * 1.5


static func for_opponent(opponent: OpponentData) -> float:
	var skill_total := 0.0
	for target: String in opponent.skills:
		skill_total += float(opponent.skills[target])
	# Opponents list only their notable skills; approximate a capability score.
	return from_stats(opponent.stats, skill_total * 0.35, opponent.level)


## Opponent power / champion power → experience multiplier from config bands.
static func difficulty_multiplier(ratio: float) -> float:
	var bands := Content.config.difficulty_bands
	var multiplier := bands[0].y if not bands.is_empty() else 1.0
	for band: Vector2 in bands:
		if ratio >= band.x:
			multiplier = band.y
	return multiplier


static func difficulty_label(ratio: float) -> String:
	if ratio < 0.85:
		return "Much weaker"
	if ratio < 1.12:
		return "Even match"
	if ratio < 1.35:
		return "Stronger"
	return "Very difficult"
