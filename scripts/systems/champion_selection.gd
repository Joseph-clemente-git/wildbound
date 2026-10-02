class_name ChampionSelection
extends RefCounted
## Choosing which champion enters a fight, after the fight has been chosen.
## Works for any number of champions; nothing here depends on species.

const LOW_HAPPINESS := 40.0


## Every champion, ready ones first, otherwise in roster order.
static func candidates(trial: TrialData) -> Array[Champion]:
	var ready: Array[Champion] = []
	var resting: Array[Champion] = []
	for champion in Game.champions:
		if is_ready(champion, trial):
			ready.append(champion)
		else:
			resting.append(champion)
	return ready + resting


static func is_ready(champion: Champion, trial: TrialData) -> bool:
	return TrialSystem.champion_blocker(champion, trial).is_empty()


## Why a champion cannot enter, in plain words with what to do about it.
static func blocker(champion: Champion, trial: TrialData) -> String:
	if champion.knocked_out:
		var minutes := ceili(ConditionSystem.knockout_seconds_left(champion, Game.now()) / 60.0)
		return "Recovering from a knockout (%d min). Rest at the lodge or wait." % maxi(minutes, 1)
	if champion.energy < trial.energy_cost:
		return "Needs %d energy (has %d). Rest at the lodge." % [trial.energy_cost, roundi(champion.energy)]
	return ""


## Things worth knowing that do not stop the champion from entering.
static func notes(champion: Champion, trial: TrialData) -> PackedStringArray:
	var result := PackedStringArray()
	if champion.weapon_id.is_empty():
		result.append("No weapon equipped")
	if champion.happiness < LOW_HAPPINESS:
		result.append("Feeling %s — spend time together at the lodge" % champion.mood_name().to_lower())
	if is_ready(champion, trial):
		result.append("Energy after entering: %d" % roundi(champion.energy - trial.energy_cost))
		var after := champion.energy - trial.energy_cost
		if ConditionEffects.stamina_factor(after) < 0.97:
			result.append("Will fight tired — less stamina")
	return result


## Who is preselected: the champion the Keeper was working with if ready,
## else the first ready one, else the first in the roster.
static func default_choice(trial: TrialData) -> Champion:
	var current := Game.champion()
	if current != null and is_ready(current, trial):
		return current
	var ordered := candidates(trial)
	return ordered[0] if not ordered.is_empty() else null


## Commits the choice: the chosen champion becomes the one the battle,
## its result and its growth apply to.
static func choose(champion: Champion, trial: TrialData) -> String:
	var reason := blocker(champion, trial)
	if reason.is_empty():
		Game.select_champion(champion.uid)
	return reason
