class_name ConditionSystem
extends RefCounted
## Energy, happiness and recovery rules (mechanics §70-74, prompts 13 & 30).
##
## Energy is the outside-of-battle physical condition; happiness is bond and
## morale. Both have simple cost/time models and never become hard punishments.


## Passive rest over real time, and knockouts wearing off on their own.
## Returns a list of events ("energy", "recovered_ko") for the UI.
static func apply_passive(champion: Champion, now: float) -> Array[String]:
	var events: Array[String] = []
	var config := Content.config
	if champion.last_energy_tick <= 0.0 or champion.last_energy_tick > now:
		champion.last_energy_tick = now
	var elapsed := now - champion.last_energy_tick
	var points := floori(elapsed / config.passive_energy_regen_seconds)
	if points > 0:
		champion.last_energy_tick += points * config.passive_energy_regen_seconds
		if champion.energy < champion.max_energy():
			champion.restore_energy(points)
			events.append("energy")
	if champion.knocked_out and now - champion.knocked_out_at >= config.knockout_recovery_seconds:
		recover_from_knockout(champion)
		events.append("recovered_ko")
	return events


static func knock_out(champion: Champion, now: float) -> void:
	champion.knocked_out = true
	champion.knocked_out_at = now
	champion.changed.emit()


## Clears a knockout. Recovering teaches a little resilience (mechanics §18).
static func recover_from_knockout(champion: Champion) -> void:
	if not champion.knocked_out:
		return
	champion.knocked_out = false
	champion.experience.add("resilience", 8.0)
	champion.changed.emit()


static func knockout_seconds_left(champion: Champion, now: float) -> float:
	if not champion.knocked_out:
		return 0.0
	return maxf(Content.config.knockout_recovery_seconds - (now - champion.knocked_out_at), 0.0)


static func short_rest_ready(champion: Champion, now: float) -> bool:
	return now - champion.last_short_rest >= Content.config.short_rest_cooldown_seconds


static func short_rest_seconds_left(champion: Champion, now: float) -> float:
	return maxf(Content.config.short_rest_cooldown_seconds - (now - champion.last_short_rest), 0.0)


## Free rest at the lodge with a cooldown. Restores a little energy and mood.
static func short_rest(champion: Champion, now: float) -> bool:
	if not short_rest_ready(champion, now):
		return false
	champion.last_short_rest = now
	champion.restore_energy(Content.config.short_rest_energy)
	champion.change_happiness(3.0)
	return true


## Paid care: herbs, a warm meal and attention. Also clears a knockout.
static func care(champion: Champion, profile: OwnerProfile) -> bool:
	var config := Content.config
	if not profile.spend(config.care_coin_cost):
		return false
	champion.restore_energy(config.care_energy)
	champion.change_happiness(config.care_happiness)
	recover_from_knockout(champion)
	return true


## Happiness after a battle result. Repeated losses weigh a little more.
static func happiness_after_battle(champion: Champion, won: bool) -> float:
	var config := Content.config
	if won:
		return champion.change_happiness(config.happiness_win)
	var delta := float(config.happiness_loss)
	if champion.loss_streak >= 2:
		delta += config.happiness_loss_streak_extra
	return champion.change_happiness(delta)
