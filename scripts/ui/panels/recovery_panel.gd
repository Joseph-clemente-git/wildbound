extends LodgePanel
## Rest Area: energy, bond and knockout recovery with a simple cost/time
## model (mechanics §70-74, prompt 30).

var _timer := 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		Game.tick_condition()
		rebuild()


func build(container: VBoxContainer) -> void:
	set_title("Rest Area")
	var champion := Game.champion()
	var config := Content.config
	var now := Game.now()
	var status := card("%s's condition" % champion.name, "Energy recovers by itself over time (1 point every %d minutes). Knockouts wear off after %d minutes of rest." % [
			roundi(config.passive_energy_regen_seconds / 60.0), roundi(config.knockout_recovery_seconds / 60.0)])
	status.add_child(UiKit.stat_row("Energy", "%d / %d" % [champion.energy, champion.max_energy()],
			champion.energy / champion.max_energy(), UiTheme.ENERGY))
	status.add_child(UiKit.stat_row("Bond — %s" % champion.mood_name(), "%d / %d" % [champion.happiness, champion.max_happiness()],
			champion.happiness / champion.max_happiness(), UiTheme.HAPPINESS))
	if champion.knocked_out:
		var left := ConditionSystem.knockout_seconds_left(champion, now)
		status.add_child(UiKit.label("Knocked out — recovering (%d:%02d left)." % [int(left) / 60, int(left) % 60], "", true))
	var rest := card("Nap in the hay", "A short rest: +%d energy and a little comfort. Free, once every %d minutes." % [
			config.short_rest_energy, roundi(config.short_rest_cooldown_seconds / 60.0)])
	var ready := ConditionSystem.short_rest_ready(champion, now)
	var rest_button := UiKit.primary_button("Rest" if ready else "Resting again in %ds" % ceili(ConditionSystem.short_rest_seconds_left(champion, now)), _rest)
	rest_button.disabled = not ready
	rest.add_child(rest_button)
	var care := card("Care and a warm meal", "Herbs, brushing and a hearty meal: +%d energy, +%d bond, clears a knockout." % [
			config.care_energy, config.care_happiness])
	var care_button := UiKit.button("Care (◉ %d)" % config.care_coin_cost, _care)
	care_button.disabled = not Game.profile.can_afford(config.care_coin_cost)
	care.add_child(care_button)
	card("Why rest matters", "Training while tired lowers bond, and tired champions cannot enter trials. Bond lightly improves training — it is never a punishment.")


func _rest() -> void:
	if ConditionSystem.short_rest(Game.champion(), Game.now()):
		Sfx.play("ui_confirm")
		Game.set_flag("rested_once")
		Game.save()
		toast("%s curls up in the hay." % Game.champion().name, UiTheme.GOOD)


func _care() -> void:
	if ConditionSystem.care(Game.champion(), Game.profile):
		Sfx.play("growth")
		Game.set_flag("rested_once")
		Game.save()
		toast("%s looks happy and refreshed." % Game.champion().name, UiTheme.GOOD)
	else:
		toast("Not enough coins.", UiTheme.BAD)
