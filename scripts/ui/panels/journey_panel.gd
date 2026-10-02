extends LodgePanel
## Journey at the Map Board: trials of the current region and, once unlocked,
## the World Map (story §23, §26, §33).


func build(container: VBoxContainer) -> void:
	set_title("Journey — Home Valley")
	var champion := Game.champion()
	if Game.is_flag_set("world_map_unlocked"):
		var map := card("World Map", "Marten's map of the valley and the regions beyond.")
		map.add_child(UiKit.primary_button("Open the World Map", func() -> void: Router.go("world_map")))
	card("Trials", "Organized trials: prove your champion's skill, earn coins and grow the lodge's reputation. Defeat means a knockout, never worse.")
	for trial: TrialData in Content.list("trials"):
		if trial.region_id == "home_valley":
			_trial_card(champion, trial)


func _trial_card(champion: Champion, trial: TrialData) -> void:
	var opponent := Content.opponent(trial.opponent_id)
	var cleared := Game.is_flag_set(trial.cleared_flag())
	var column := card("%s%s" % [trial.display_name, "  ✓" if cleared else ""], trial.description)
	var weapon := Content.weapon(opponent.weapon_id)
	var ratio := PowerRating.for_opponent(opponent) / maxf(champion.power_rating(), 1.0)
	column.add_child(UiKit.label("%s — %s · Level %d · %s%s" % [opponent.display_name, opponent.title, opponent.level,
			weapon.display_name, (" + " + Content.ability(opponent.magic_ability_id).display_name) if not opponent.magic_ability_id.is_empty() else ""], ""))
	column.add_child(UiKit.label("%s · %s trial · Energy %d · Reward ◉ %d%s" % [PowerRating.difficulty_label(ratio),
			trial.tier.capitalize(), trial.energy_cost, trial.coins,
			"" if cleared else " (+%d first victory)" % trial.first_clear_coins], "DimLabel", true))
	var missing := PackedStringArray()
	for flag in trial.requires_flags:
		if not Game.is_flag_set(flag):
			missing.append(_flag_text(flag))
	if not missing.is_empty():
		column.add_child(UiKit.label("Locked: " + ", ".join(missing), "DimLabel", true))
		return
	var prepare := UiKit.primary_button("Prepare", func() -> void: Router.go("battle_prep", {"trial": trial.id}))
	if not ResourceLoader.exists(Router.ROUTES["battle_prep"]):
		prepare.disabled = true
	column.add_child(prepare)


func _flag_text(flag: String) -> String:
	match flag:
		"equipped_weapon":
			return "equip a weapon"
		"trained_once":
			return "train once"
		"first_trial_done":
			return "finish the First Steps Trial"
	if flag.begins_with("cleared_"):
		var trial := Content.trial(flag.trim_prefix("cleared_"))
		if trial != null:
			return "win the " + trial.display_name
	return flag.replace("_", " ")
