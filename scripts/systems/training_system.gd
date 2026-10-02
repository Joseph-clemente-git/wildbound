class_name TrainingSystem
extends RefCounted
## Trainer-based deliberate development (mechanics §37-39, prompt 14).
##
## Trainer → Champion → Skill → Cost → Energy → Confirm → Development.
## A session costs coins and energy, respects the trainer's rarity limits, the
## champion's potential and skill prerequisites, and converts some of the
## matching banked battle experience into extra progress — the difference
## between "Experience Growth" (natural) and "Trainer Development" (deliberate).


## Everything the training screen needs to show before confirming.
## Keys: ok, reason, target, kind, primary, coin_cost, energy_cost, current_rank,
## current_value, rank_cap, progress, converted, expected, expected_text,
## overtraining, efficiency.
static func preview(trainer: TrainerData, champion: Champion, target: String, profile: OwnerProfile) -> Dictionary:
	var config := Content.config
	var result := {
		"ok": false, "reason": "", "target": target, "kind": GameEnums.target_kind(target),
		"primary": trainer.is_primary(target), "coin_cost": 0, "energy_cost": 0,
		"current_rank": champion.rank_of(target), "current_value": 0.0, "rank_cap": 0,
		"progress": 0.0, "converted": 0.0, "expected": 0.0, "expected_text": "",
		"overtraining": false, "efficiency": 1.0,
	}
	if not TrainerManager.coverage(trainer).has(target):
		result["reason"] = "%s does not teach %s at this level of expertise." % [
				trainer.display_name, SkillCatalog.target_name(target)]
		return result
	var traits := TrainerManager.active_traits(trainer)
	var efficiency := TrainerManager.rarity_efficiency(trainer) * champion.happiness_factor() \
			* TrainerTraits.progress_bonus(traits, target)
	if not trainer.is_primary(target):
		efficiency *= config.secondary_discipline_factor
	result["efficiency"] = efficiency
	var rank := champion.rank_of(target)
	result["coin_cost"] = int(round((config.training_base_coin_cost + config.training_coin_cost_per_rank * rank)
			* float(TrainerTraits.effect(traits, "coin_factor", 1.0))))
	result["energy_cost"] = int(round(config.training_energy_cost * float(TrainerTraits.effect(traits, "energy_factor", 1.0))))
	result["overtraining"] = champion.energy - float(result["energy_cost"]) < config.overtraining_energy_threshold \
			and not bool(TrainerTraits.effect(traits, "no_overtraining", false))

	# Experience the trainer can build on.
	var track := SkillCatalog.conversion_track(target)
	var converted := 0.0
	if not track.is_empty():
		converted = champion.experience.get_xp(track) * config.experience_conversion_rate \
				* float(TrainerTraits.effect(traits, "conversion_factor", 1.0))
		converted = minf(converted, champion.experience.get_xp(track))
	result["converted"] = converted

	if result["kind"] == "stat":
		var stat := GameEnums.target_id(target)
		var value := champion.developed_stat(stat)
		var cap := minf(TrainerManager.stat_cap(trainer), champion.potential(stat))
		result["current_value"] = value
		if value >= cap - 0.01:
			result["reason"] = "%s cannot develop %s further. %s" % [trainer.display_name, GameEnums.stat_name(stat),
					"It has reached its potential." if cap >= champion.potential(stat) else "A more renowned mentor is needed."]
			return result
		var room := champion.potential_room(stat)
		var slowdown := lerpf(config.potential_min_factor, 1.0, clampf(room / (1.0 - config.potential_slowdown_start), 0.0, 1.0))
		var points := (config.training_stat_points + converted * config.experience_conversion_value * 0.05) \
				* efficiency * slowdown
		points = minf(points, cap - value)
		result["expected"] = points
		result["expected_text"] = "%s %.1f → %.1f" % [GameEnums.stat_name(stat), value, value + points]
	else:
		var cap := mini(TrainerManager.rank_cap(trainer), champion.rank_cap(target))
		result["rank_cap"] = cap
		var missing := missing_prerequisites(champion, target)
		if not missing.is_empty():
			result["reason"] = "Requires " + ", ".join(missing) + "."
			return result
		if rank >= cap and (rank >= GameEnums.Rank.MASTER or champion.skills.progress_ratio(target) >= 0.99):
			result["reason"] = "%s has taught all they can of %s (%s)." % [trainer.display_name,
					SkillCatalog.target_name(target), GameEnums.rank_name(cap)]
			return result
		var slowdown := 1.0 - 0.5 * float(rank) / maxf(champion.rank_cap(target), 1.0)
		var progress := (config.training_base_progress + converted * config.experience_conversion_value) \
				* efficiency * slowdown
		result["progress"] = progress
		if rank == GameEnums.Rank.NONE:
			result["expected_text"] = "Learn %s (%s)" % [SkillCatalog.target_name(target),
					GameEnums.rank_name(SkillMatrix.first_rank(target))]
		else:
			result["expected_text"] = "%s +%d%% toward %s" % [SkillCatalog.target_name(target),
					roundi(progress / SkillMatrix.progress_needed(rank) * 100.0),
					GameEnums.rank_name(mini(rank + 1, GameEnums.Rank.MASTER))]
	if champion.knocked_out:
		result["reason"] = "%s is recovering from a knockout." % champion.name
		return result
	if champion.energy < result["energy_cost"]:
		result["reason"] = "%s is too tired (%d energy needed)." % [champion.name, result["energy_cost"]]
		return result
	if profile.coins < result["coin_cost"]:
		result["reason"] = "You need %d coins." % result["coin_cost"]
		return result
	if not TrainerManager.is_active(profile, trainer.id):
		result["reason"] = "%s is not an active mentor." % trainer.display_name
		return result
	result["ok"] = true
	return result


static func missing_prerequisites(champion: Champion, target: String) -> PackedStringArray:
	var missing := PackedStringArray()
	var needs: Dictionary = SkillCatalog.PREREQUISITES.get(target, {})
	for need: String in needs:
		if champion.rank_of(need) < int(needs[need]):
			missing.append("%s %s" % [SkillCatalog.target_name(need), GameEnums.rank_name(needs[need])])
	return missing


## Performs a session. Returns the preview merged with outcome keys:
## gained (stat points), ranks (Array[int] reached), happiness, text.
static func train(trainer: TrainerData, champion: Champion, target: String, profile: OwnerProfile) -> Dictionary:
	var config := Content.config
	var result := preview(trainer, champion, target, profile)
	if not result["ok"]:
		return result
	profile.spend(result["coin_cost"])
	champion.consume_energy(result["energy_cost"])
	var track := SkillCatalog.conversion_track(target)
	if not track.is_empty():
		champion.experience.consume(track, result["converted"])
	var lines := PackedStringArray()
	result["ranks"] = []
	if result["kind"] == "stat":
		var stat := GameEnums.target_id(target)
		var gained := champion.add_trained(stat, result["expected"])
		result["gained"] = gained
		lines.append("%s +%.1f" % [GameEnums.stat_name(stat), gained])
	else:
		var reached := champion.skills.add_progress(target, result["progress"], result["rank_cap"])
		result["ranks"] = reached
		for rank in reached:
			lines.append("%s reached %s!" % [SkillCatalog.target_name(target), GameEnums.rank_name(rank)])
		if reached.is_empty():
			lines.append("%s progress +%d%%" % [SkillCatalog.target_name(target),
					roundi(result["progress"] / SkillMatrix.progress_needed(champion.skills.get_rank(target)) * 100.0)])
	if result["converted"] > 0.5:
		lines.append("Built on %d battle experience" % roundi(result["converted"]))
	var traits := TrainerManager.active_traits(trainer)
	var mood := float(config.happiness_overtraining) if result["overtraining"] else \
			float(config.happiness_training) + float(TrainerTraits.effect(traits, "happiness_bonus", 0.0))
	result["happiness"] = champion.change_happiness(mood)
	if result["overtraining"]:
		lines.append("%s is worn out — rest soon." % champion.name)
	profile.trainer_sessions[trainer.id] = int(profile.trainer_sessions.get(trainer.id, 0)) + 1
	profile.changed.emit()
	champion.changed.emit()
	result["text"] = "\n".join(lines)
	return result
