class_name TrialSystem
extends RefCounted
## Trials: who may enter, what it costs and what a result changes
## (mechanics §70-74, story §21, §33-37).

const LOSS_ANIMAL_XP_FACTOR := 0.5
const LOSS_COIN_FACTOR := 0.3
const LOSS_OWNER_XP_FACTOR := 0.4


static func is_unlocked(trial: TrialData) -> bool:
	for flag in trial.requires_flags:
		if not Game.is_flag_set(flag):
			return false
	return TrainerManager.is_region_open(Game.profile, trial.region_id)


## Empty when the champion can enter, otherwise why not.
static func entry_blocker(champion: Champion, trial: TrialData) -> String:
	if not is_unlocked(trial):
		return "This trial is not open yet."
	if champion.knocked_out:
		return "%s is recovering from a knockout. Rest first." % champion.name
	if champion.energy < trial.energy_cost:
		return "%s needs %d energy for this trial (has %d)." % [champion.name, trial.energy_cost, roundi(champion.energy)]
	return ""


static func enter(champion: Champion, trial: TrialData) -> String:
	var blocker := entry_blocker(champion, trial)
	if blocker.is_empty():
		champion.consume_energy(trial.energy_cost)
		Game.save()
	return blocker


## Applies the outcome of a battle and returns the rewards summary merged into it.
static func apply_result(outcome: Dictionary) -> Dictionary:
	var champion := Game.champion()
	var profile := Game.profile
	var trial := Content.trial(outcome["trial_id"])
	var won: bool = outcome["won"]
	var first_win := won and not Game.is_flag_set(trial.cleared_flag())
	var first_attempt := not Game.is_flag_set("attempted_" + trial.id)
	var coins := trial.coins if won else roundi(trial.coins * LOSS_COIN_FACTOR)
	var owner_xp := trial.owner_xp if won else roundi(trial.owner_xp * LOSS_OWNER_XP_FACTOR)
	if first_win:
		coins += trial.first_clear_coins
		owner_xp += trial.first_clear_owner_xp
	if outcome.get("forfeited", false):
		coins = 0
		owner_xp = roundi(owner_xp * 0.5)
	var animal_xp := trial.animal_xp if won else roundi(trial.animal_xp * LOSS_ANIMAL_XP_FACTOR)
	var keeper_level := profile.level
	var animal_level := champion.level
	var energy_before := champion.energy
	profile.earn(coins)
	var owner_levels := profile.add_xp(owner_xp)
	var animal_levels := champion.add_xp(animal_xp)
	if won:
		champion.wins += 1
		champion.loss_streak = 0
	else:
		champion.losses += 1
		champion.loss_streak += 1
	var happiness := ConditionSystem.happiness_after_battle(champion, won)
	if not won and not outcome.get("forfeited", false):
		ConditionSystem.knock_out(champion, Game.now())
	champion.record_battle({
		"trial": trial.display_name, "trial_id": trial.id, "opponent": trial.opponent_id, "won": won,
		"duration": roundi(outcome.get("duration", 0.0)), "time": Game.now(),
	})
	Game.set_flag("attempted_" + trial.id)
	if trial.tutorial or trial.id == "first_steps":
		Game.set_flag("first_trial_done")
	if won:
		Game.set_flag(trial.cleared_flag())
	var story := ""
	if first_win and not trial.story_after_win.is_empty():
		story = trial.story_after_win
	elif first_attempt and not trial.story_after_first.is_empty():
		story = trial.story_after_first
	var result := outcome.duplicate()
	result.merge({
		"coins": coins, "owner_xp": owner_xp, "animal_xp": animal_xp, "first_win": first_win,
		"owner_level_before": keeper_level, "owner_levels": owner_levels,
		"animal_level_before": animal_level, "animal_levels": animal_levels,
		"happiness": happiness, "energy_before": energy_before, "energy_after": champion.energy,
		"knocked_out": champion.knocked_out, "story": story,
		"suggestion": suggest_training(champion, outcome.get("experience", {})),
	}, true)
	Game.save()
	return result


## Story §39: after a battle, point at the experience worth building on and a
## mentor who could develop it. Returns {} when nothing stands out.
static func suggest_training(champion: Champion, gains: Dictionary) -> Dictionary:
	var best_track := ""
	var best := 0.0
	for track: String in gains:
		if float(gains[track]) > best:
			best = float(gains[track])
			best_track = track
	if best_track.is_empty() or best < 8.0:
		return {}
	var targets: Array = ExperienceTracks.targets_for(best_track)
	for trainer in TrainerManager.owned(Game.profile):
		for target: String in targets + _skills_for_track(best_track):
			if TrainerManager.coverage(trainer).has(target):
				return {"track": best_track, "amount": best, "trainer": trainer.id, "target": target,
						"active": TrainerManager.is_active(Game.profile, trainer.id)}
	return {"track": best_track, "amount": best, "trainer": "", "target": ""}


static func _skills_for_track(track: String) -> Array:
	var result: Array = []
	for target: String in SkillCatalog.CONVERSION_TRACKS:
		if SkillCatalog.CONVERSION_TRACKS[target] == track:
			result.append(target)
	return result
