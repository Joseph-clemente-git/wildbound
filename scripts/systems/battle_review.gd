class_name BattleReview
extends RefCounted
## The mentors' read of a simulated battle (Stage 22): what worked, what went
## wrong, and which trainer could develop the answer. It reads only the
## battle's tallies — nothing is guessed from level or power — and points at
## a development target the Keeper's own trainers cover, together with the
## banked experience that training would convert.
##
## A lesson is {"text", "targets": [development targets, best first]}.

## Below this, a tally is too small to call a pattern.
const PATTERN := 3


## `simulation` is BattleOutcome.to_dict(); `gains` the experience banked.
## Returns {"strengths": [lesson], "weaknesses": [lesson], "suggestion": {}}.
static func review(champion: Champion, profile: OwnerProfile, simulation: Dictionary, gains: Dictionary) -> Dictionary:
	var fighters: Array = simulation.get("fighters", [])
	if fighters.size() < 2:
		return {"strengths": [], "weaknesses": [], "suggestion": {}}
	var me: Dictionary = _side(fighters, 0)
	var foe: Dictionary = _side(fighters, 1)
	var won := int(simulation.get("winner_team", -1)) == 0
	var strengths := _strengths(champion, me)
	var weaknesses := _weaknesses(champion, me, foe, won)
	# A defeat is about the answer to what went wrong; a victory builds on
	# what worked. Either way, fall back to the other.
	var order: Array = weaknesses + strengths if not won else strengths + weaknesses
	var suggestion := {}
	for lesson: Dictionary in order:
		suggestion = _mentor_for(champion, profile, lesson, gains)
		if not suggestion.is_empty():
			break
	return {"strengths": strengths, "weaknesses": weaknesses, "suggestion": suggestion}


static func _strengths(champion: Champion, me: Dictionary) -> Array:
	var result: Array = []
	var name := champion.name
	var dodges := _n(me, "dodges")
	if dodges >= PATTERN:
		result.append(_lesson("%s read the attacks and dodged %d times." % [name, dodges],
				["skill:dodge", "stat:evasion", "skill:dodge_control"]))
	var guards := _n(me, "blocks") + _n(me, "parries")
	if guards >= PATTERN:
		result.append(_lesson("%s's guard held — %d blows blocked or parried." % [name, guards],
				["skill:block", "stat:defense", "skill:block_control"]))
	if _n(me, "heavy_hits") >= PATTERN or _n(me, "staggers_caused") + _n(me, "knockdowns_caused") >= 2:
		result.append(_lesson("Heavy blows broke the opponent's footing.", ["stat:strength", "skill:attack"]))
	if _n(me, "openings_punished") >= 2:
		result.append(_lesson("%s punished %d openings." % [name, _n(me, "openings_punished")],
				["skill:timing", "stat:attack", "skill:attack_control"]))
	if _n(me, "max_combo") >= 3:
		result.append(_lesson("Combinations flowed — %d blows in a row." % _n(me, "max_combo"),
				["stat:attack_speed", "skill:attack"]))
	if _n(me, "flank_hits") >= 2:
		result.append(_lesson("Moving to the flank found an open side.", ["skill:positioning", "stat:agility"]))
	return result


static func _weaknesses(champion: Champion, me: Dictionary, foe: Dictionary, won: bool) -> Array:
	var result: Array = []
	var name := champion.name
	var exhaustions := _n(me, "exhaustions")
	if exhaustions >= 1:
		result.append(_lesson("%s ran out of breath %s." % [name, "once" if exhaustions == 1 else "%d times" % exhaustions],
				["stat:endurance", "skill:stamina", "skill:stamina_discipline"]))
	var taken := _n(foe, "hits_landed")
	var answered := _n(me, "dodges") + _n(me, "blocks") + _n(me, "parries")
	if taken >= 6 and answered * 2 < taken:
		result.append(_lesson("%d blows landed on %s with little answer." % [taken, name],
				["skill:block", "skill:dodge", "stat:defense", "stat:evasion"]))
	var stopped := _n(me, "blows_evaded_by_foe") + _n(me, "blows_blocked_by_foe") + _n(me, "whiffs")
	if stopped >= maxi(4, _n(me, "hits_landed")):
		result.append(_lesson("Most of %s's attacks were dodged, blocked or missed." % name,
				["skill:timing", "skill:attack", "stat:attack_speed"]))
	if _n(me, "staggered") + _n(me, "knocked_down") >= PATTERN:
		result.append(_lesson("%s was knocked off balance %d times." % [name, _n(me, "staggered") + _n(me, "knocked_down")],
				["skill:recovery", "stat:health", "skill:defense"]))
	if not won and float(foe.get("health_ratio", 1.0)) > 0.7:
		result.append(_lesson("The opponent was barely hurt.", ["stat:attack", "stat:strength", "skill:attack"]))
	return result


## The first owned trainer (active ones first) who covers one of the
## lesson's targets.
static func _mentor_for(champion: Champion, profile: OwnerProfile, lesson: Dictionary, gains: Dictionary) -> Dictionary:
	var trainers := TrainerManager.owned(profile)
	trainers.sort_custom(func(a: TrainerData, b: TrainerData) -> bool:
		return TrainerManager.is_active(profile, a.id) and not TrainerManager.is_active(profile, b.id))
	for target: String in lesson["targets"]:
		for trainer in trainers:
			if not TrainerManager.coverage(trainer).has(target):
				continue
			var track := SkillCatalog.conversion_track(target)
			return {"reason": lesson["text"], "trainer": trainer.id, "target": target, "track": track,
					"amount": float(gains.get(track, 0.0)),
					"banked": champion.experience.get_xp(track) if not track.is_empty() else 0.0,
					"active": TrainerManager.is_active(profile, trainer.id)}
	return {}


static func _lesson(text: String, targets: Array) -> Dictionary:
	return {"text": text, "targets": targets}


static func _side(fighters: Array, team: int) -> Dictionary:
	for fighter: Dictionary in fighters:
		if int(fighter.get("team", -1)) == team:
			return fighter
	return {}


static func _n(tally: Dictionary, key: String) -> int:
	return int(tally.get(key, 0))
