class_name GrowthSystem
extends RefCounted
## Natural growth from banked experience (mechanics §21, prompt 09).
##
## Battle → Experience → Threshold → Growth Event → Natural Development.
## There is no manual stat allocation: each track develops the attributes it
## represents, limited by training potential.

## Fundamental skill nudged by each core track's growth.
const RELATED_SKILL := {
	"offensive": "skill:attack",
	"tempo": "skill:attack_control",
	"agility": "skill:movement",
	"evasion": "skill:dodge",
	"defense": "skill:block",
	"endurance": "skill:stamina",
	"resilience": "skill:recovery",
}

## Share of the growth amount each stat target receives.
const STAT_SHARES := {
	"resilience": {"stat:health": 1.0, "stat:endurance": 0.5},
}


## Resolves every growth threshold crossed. Returns growth event dictionaries:
## {"track", "target", "amount", "rank", "text"}.
static func process(champion: Champion) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var tracks := champion.experience.xp.keys()
	tracks.sort()
	for track: String in tracks:
		var guard := 0
		while champion.experience.get_xp(track) >= champion.experience.threshold(track) and guard < 10:
			guard += 1
			var grown := _grow(champion, track)
			if grown.is_empty():
				# At potential: keep the experience banked (trainers can still use it).
				champion.experience.xp[track] = champion.experience.threshold(track)
				break
			champion.experience.consume(track, champion.experience.threshold(track))
			champion.experience.record_growth(track)
			events.append_array(grown)
	if not events.is_empty():
		champion.changed.emit()
	return events


static func _grow(champion: Champion, track: String) -> Array[Dictionary]:
	var config := Content.config
	var events: Array[Dictionary] = []
	var kind := GameEnums.target_kind(track)
	if kind == "weapon" or kind == "magic":
		# Familiarity: using a weapon teaches it; magic must first be learned.
		if kind == "magic" and not champion.skills.is_learned(track):
			return events
		var cap := mini(config.natural_rank_cap, champion.rank_cap(track))
		var rank_before := champion.skills.get_rank(track)
		if rank_before >= cap and champion.skills.progress_ratio(track) >= 0.99:
			return events
		var reached := champion.skills.add_progress(track, config.growth_familiarity_amount, cap)
		events.append(_event(track, track, config.growth_familiarity_amount,
				reached.back() if not reached.is_empty() else -1,
				"%s familiarity grew" % ExperienceTracks.track_name(track)))
		return events
	var shares: Dictionary = STAT_SHARES.get(track, {})
	for target: String in ExperienceTracks.targets_for(track):
		var share: float = shares.get(target, 1.0)
		var stat := GameEnums.target_id(target)
		var gained := champion.add_natural_growth(stat, config.growth_stat_amount * share)
		if gained > 0.0:
			events.append(_event(track, target, gained, -1,
					"%s +%.1f" % [GameEnums.stat_name(stat), gained]))
	if events.is_empty():
		return events
	if RELATED_SKILL.has(track):
		var skill: String = RELATED_SKILL[track]
		var reached := champion.skills.add_progress(skill, config.growth_skill_progress, config.natural_rank_cap)
		if not reached.is_empty():
			events.append(_event(track, skill, 0.0, reached.back(),
					"%s reached %s" % [SkillCatalog.target_name(skill), GameEnums.rank_name(reached.back())]))
	return events


static func _event(track: String, target: String, amount: float, rank: int, text: String) -> Dictionary:
	return {"track": track, "target": target, "amount": amount, "rank": rank, "text": text}
