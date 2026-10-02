extends Node3D
## Battle Result (mechanics §72, story §21, §37): told as the champion's growth.
## "What did my animal learn from this battle?"
## Params: {"outcome": TrialSystem.apply_result() dictionary}

var outcome: Dictionary
var _content: VBoxContainer


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back()


func _back() -> void:
	_continue({})


func _ready() -> void:
	outcome = Router.params.get("outcome", {})
	if outcome.is_empty() or not Game.is_active():
		Router.go("lodge" if Game.is_active() else "title")
		return
	Router.back_requested.connect(_back)
	_build_backdrop()
	_build_ui()
	Sfx.play_ambient()
	Sfx.play("victory" if outcome["won"] else "defeat")


func _build_backdrop() -> void:
	WorldBuilder.environment(self, "dusk")
	WorldBuilder.ground(self, 80.0, {"ring_center": Vector2.ZERO, "ring_radius": 3.0})
	WorldBuilder.grass(self, Rect2(-12, -12, 24, 24), 1400, [Vector3(0, 0, 3.2)], 4)
	WorldBuilder.forest_ring(self, 9.0, 20.0, 30, 2, false)
	var champion := Game.champion()
	var dog := CharacterFactory.for_champion(champion)
	dog.position = Vector3(2.1, 0, -0.4)
	dog.rotation.y = deg_to_rad(20)
	var weapon := Content.weapon(champion.weapon_id)
	dog.set_weapon(weapon.weapon_type if weapon else "")
	var armor := Content.armor(champion.armor_id)
	dog.set_armor(armor.weight_class if armor else -1)
	add_child(dog)
	dog.play("victory" if outcome["won"] else "exhausted", -1.0, true)
	var camera := Camera3D.new()
	camera.position = Vector3(-0.6, 1.5, 3.6)
	add_child(camera)
	camera.look_at(Vector3(0.6, 1.1, 0))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var sheet := UiKit.panel("SheetPanel")
	sheet.anchor_right = 0.58
	sheet.anchor_bottom = 1.0
	var insets := UiKit.safe_insets()
	sheet.offset_left = 16 + insets.x
	sheet.offset_top = 16 + insets.y
	sheet.offset_bottom = -16 - insets.w
	root.add_child(sheet)
	var column := UiKit.vbox(12)
	sheet.add_child(column)
	var trial := Content.trial(outcome["trial_id"])
	column.add_child(UiKit.label("TRIAL COMPLETE — %s" % trial.display_name.to_upper(), "DimLabel"))
	var headline := UiKit.label("Victory" if outcome["won"] else ("Forfeited" if outcome.get("forfeited") else "Defeat"), "TitleLabel")
	headline.add_theme_color_override("font_color", UiTheme.GOOD if outcome["won"] else UiTheme.BAD)
	column.add_child(headline)
	var opponent := Content.opponent(outcome["opponent_id"])
	column.add_child(UiKit.label(opponent.win_line if not outcome["won"] else opponent.lose_line, "DimLabel", true))
	_content = UiKit.vbox(14)
	column.add_child(UiKit.scroll(_content))
	_learned()
	_rewards()
	_condition()
	_next_steps(column)


func _section(title: String) -> VBoxContainer:
	var panel := UiKit.panel("CardPanel")
	var column := UiKit.vbox(6)
	panel.add_child(column)
	var heading := UiKit.label(title)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	heading.add_theme_font_size_override("font_size", UiTheme.fs(24))
	column.add_child(heading)
	_content.add_child(panel)
	return column


func _learned() -> void:
	var champion := Game.champion()
	var section := _section("%s learned from the trial" % champion.name)
	var gains: Dictionary = outcome.get("experience", {})
	var tracks := gains.keys()
	tracks.sort_custom(func(a: String, b: String) -> bool: return float(gains[a]) > float(gains[b]))
	if tracks.is_empty():
		section.add_child(UiKit.label("Nothing new this time — try dodging, blocking and punishing openings.", "DimLabel", true))
	for track: String in tracks:
		var amount := float(gains[track])
		if amount < 0.5:
			continue
		section.add_child(UiKit.stat_row("%s Experience" % ExperienceTracks.track_name(track), "+%d" % roundi(amount),
				champion.experience.ratio(track), UiTheme.GOOD))
	var multiplier: float = outcome.get("difficulty_multiplier", 1.0)
	section.add_child(UiKit.label("Encounter: %s (experience ×%.2f)" % [PowerRating.difficulty_label(outcome.get("difficulty_ratio", 1.0)), multiplier], "DimLabel"))
	var growths: Array = outcome.get("growths", [])
	if not growths.is_empty():
		var growth := _section("Natural growth")
		for event: Dictionary in growths:
			var line := UiKit.label("✦ " + str(event["text"]))
			line.add_theme_color_override("font_color", UiTheme.GOOD)
			growth.add_child(line)
		Sfx.play("growth")
	var tallies: Dictionary = outcome.get("tallies", {})
	var record := _section("The fight")
	record.add_child(UiKit.label("Hits %d · Heavy %d · Staggers %d · Dodges %d (perfect %d) · Blocks %d (perfect %d)%s" % [
			tallies.get("hits", 0), tallies.get("heavy_hits", 0), tallies.get("staggers", 0), tallies.get("dodges", 0),
			tallies.get("perfect_dodges", 0), tallies.get("blocks", 0), tallies.get("perfect_blocks", 0),
			(" · Aether %d" % tallies.get("spells", 0)) if tallies.get("spells", 0) > 0 else ""], "", true))
	record.add_child(UiKit.label("Duration %d:%02d · Exhausted %d time%s" % [int(outcome.get("duration", 0)) / 60,
			int(outcome.get("duration", 0)) % 60, tallies.get("exhaustions", 0),
			"" if tallies.get("exhaustions", 0) == 1 else "s"], "DimLabel"))
	if not outcome["won"] and not outcome.get("forfeited", false):
		record.add_child(UiKit.label("Defeat teaches survival: resilience and defense grow from hard fights.", "DimLabel", true))


func _rewards() -> void:
	var section := _section("Rewards")
	section.add_child(UiKit.stat_row("Coins", "◉ +%d%s" % [outcome.get("coins", 0), "  (first victory bonus)" if outcome.get("first_win") else ""]))
	section.add_child(UiKit.stat_row("Lodge reputation (Keeper XP)", "+%d" % outcome.get("owner_xp", 0)))
	if outcome.get("owner_levels", 0) > 0:
		var level := UiKit.label("Keeper level %d! %s" % [Game.profile.level, Game.profile.lodge_title()])
		level.add_theme_color_override("font_color", UiTheme.ACCENT)
		section.add_child(level)
	section.add_child(UiKit.stat_row("%s XP" % Game.champion().name, "+%d" % outcome.get("animal_xp", 0)))
	if outcome.get("animal_levels", 0) > 0:
		section.add_child(UiKit.label("%s reached level %d." % [Game.champion().name, Game.champion().level], "", true))


func _condition() -> void:
	var champion := Game.champion()
	var section := _section("Condition")
	section.add_child(UiKit.stat_row("Energy", "%d → %d" % [roundi(outcome.get("energy_before", 0.0)) + Content.trial(outcome["trial_id"]).energy_cost,
			roundi(champion.energy)], champion.energy / champion.max_energy(), UiTheme.ENERGY))
	var delta: float = outcome.get("happiness", 0.0)
	section.add_child(UiKit.stat_row("Bond", "%s%d (%s)" % ["+" if delta >= 0 else "", roundi(delta), champion.mood_name()],
			champion.happiness / champion.max_happiness(), UiTheme.HAPPINESS))
	if outcome.get("knocked_out", false):
		section.add_child(UiKit.label("%s was knocked out and needs rest at the lodge before the next trial." % champion.name, "", true))


func _next_steps(column: VBoxContainer) -> void:
	var suggestion: Dictionary = outcome.get("suggestion", {})
	var row := UiKit.hbox(12)
	if not suggestion.is_empty():
		var trainer := Content.trainer(suggestion.get("trainer", ""))
		var text := "%s gained significant %s Experience." % [Game.champion().name, ExperienceTracks.track_name(suggestion["track"])]
		if trainer != null:
			text += " %s (%s) can build on it%s." % [trainer.display_name, trainer.title,
					"" if suggestion.get("active", false) else " once active"]
		column.add_child(UiKit.label(text, "", true))
		if trainer != null and suggestion.get("active", false):
			row.add_child(UiKit.button("Train %s" % SkillCatalog.target_name(suggestion["target"]), _continue.bind(
					{"panel": "training", "options": {"trainer": trainer.id, "target": suggestion["target"]}})))
	row.add_child(UiKit.spacer(false))
	if outcome.get("knocked_out", false):
		# First failure teaches recovery: one clear, low-stakes next step.
		row.add_child(UiKit.button("Return to the lodge", _continue.bind({})))
		row.add_child(UiKit.primary_button("Rest & recover", _continue.bind({"panel": "recovery"}), 260))
	else:
		row.add_child(UiKit.primary_button("Return to the lodge", _continue.bind({}), 260))
	column.add_child(row)


func _continue(lodge_params: Dictionary) -> void:
	var story: String = outcome.get("story", "")
	var params := {"panel": lodge_params.get("panel", "")}
	if lodge_params.has("options"):
		params["panel_options"] = lodge_params["options"]
	if not story.is_empty():
		Router.go("story", {"event": story, "next": "lodge", "next_params": params})
	else:
		Router.go("lodge", params)
