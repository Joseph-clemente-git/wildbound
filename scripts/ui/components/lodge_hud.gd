class_name LodgeHud
extends Control
## Lodge overlay, revised with the ui-ux-game principles:
## - Less is more: compact chips around the edges instead of a full-width
##   bar, so the 3D lodge stays the visual priority.
## - State is always visible: reputation, coins, mentors, energy and bond.
## - Progressive disclosure: navigation appears as the story introduces each
##   system, with a NEW badge until first opened and a dot when something
##   there needs attention (tab-navigation-with-badges pattern).

signal panel_requested(panel_id: String)
signal objective_requested(station: String)

## Panel -> [label, flag that reveals it ("" = always)]
const NAV := [
	["champion", "Champion", ""],
	["trainers", "Mentors", ""],
	["training", "Train", "met_first_trainer"],
	["equipment", "Equipment", "met_first_trainer"],
	["journey", "Journey", "trained_once"],
	["aether", "Aether", "first_trial_done"],
	["recovery", "Rest", "first_trial_done"],
	["codex", "Codex", "codex_unlocked"],
]

var _lodge_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _coins: Label
var _mentors: Label
var _champion_label: Label
var _energy_bar: ProgressBar
var _energy_text: Label
var _happiness_bar: ProgressBar
var _happiness_text: Label
var _objective_card: PanelContainer
var _objective_text: Label
var _objective_hint: Label
var _nav_row: HBoxContainer
var _shown_coins := -1.0
var _coin_tween: Tween


static func is_panel_unlocked(panel_id: String) -> bool:
	for entry: Array in NAV:
		if entry[0] == panel_id:
			return Game.is_flag_set(entry[2])
	return true


## Whether something in a panel deserves the player's attention right now.
static func needs_attention(panel_id: String) -> bool:
	var profile := Game.profile
	var champion := Game.champion()
	if profile == null or champion == null:
		return false
	match panel_id:
		"champion":
			for technique: TechniqueData in Content.list("techniques"):
				if TechniqueSystem.learn_blocker(champion, technique, profile).is_empty():
					return true
		"trainers":
			if TrainerManager.free_slots(profile) > 0:
				for trainer in TrainerManager.owned(profile):
					if not TrainerManager.is_active(profile, trainer.id):
						return true
				for trainer in TrainerManager.recruitable(profile):
					if profile.can_afford(trainer.recruit_cost):
						return true
		"training":
			return not TrainerManager.active(profile).is_empty() and not champion.knocked_out \
					and champion.energy >= Content.config.training_energy_cost \
					and profile.coins >= Content.config.training_base_coin_cost
		"journey":
			if not champion.can_fight():
				return false
			for trial: TrialData in Content.list("trials"):
				if TrialSystem.is_unlocked(trial) and not Game.is_flag_set(trial.cleared_flag()):
					return true
		"recovery":
			return champion.knocked_out or (champion.energy < 30.0 and ConditionSystem.short_rest_ready(champion, Game.now()))
		"equipment":
			return champion.weapon_id.is_empty() and not EquipmentSystem.owned(profile, "weapon").is_empty()
		"aether":
			if champion.equipped_ability.is_empty():
				for school: String in GameEnums.MAGIC_SCHOOLS:
					if champion.skills.is_learned("magic:" + school):
						return true
	return false


static func is_new(panel_id: String) -> bool:
	return is_panel_unlocked(panel_id) and not Game.is_flag_set("seen_" + panel_id)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	var safe := UiKit.safe_area(14)
	add_child(safe)
	var column := UiKit.vbox(10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	column.add_child(_build_top_row())
	column.add_child(_build_objective())
	column.add_child(UiKit.spacer())
	_nav_row = UiKit.hbox(8)
	_nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_nav_row)


func _chip() -> PanelContainer:
	var chip := UiKit.panel("ChipPanel")
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	return chip


func _build_top_row() -> Control:
	var row := UiKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lodge reputation chip.
	var lodge := _chip()
	var lodge_column := UiKit.vbox(2)
	var lodge_top := UiKit.hbox(8)
	_lodge_label = UiKit.label("", "DimLabel")
	lodge_top.add_child(_lodge_label)
	_level_label = UiKit.label("")
	lodge_top.add_child(_level_label)
	lodge_column.add_child(lodge_top)
	_xp_bar = UiKit.bar(0, 1, UiTheme.ACCENT, 6)
	_xp_bar.custom_minimum_size.x = 200
	lodge_column.add_child(_xp_bar)
	lodge.add_child(lodge_column)
	row.add_child(lodge)
	# Coins chip.
	var coins := _chip()
	_coins = UiKit.label("")
	_coins.add_theme_color_override("font_color", UiTheme.ACCENT)
	coins.add_child(_coins)
	row.add_child(coins)
	# Mentor slots chip.
	var mentors := _chip()
	_mentors = UiKit.label("")
	mentors.add_child(_mentors)
	row.add_child(mentors)
	row.add_child(UiKit.spacer(false))
	# Champion condition chip.
	var condition := _chip()
	var condition_column := UiKit.vbox(2)
	condition_column.custom_minimum_size.x = 230
	_champion_label = UiKit.label("")
	condition_column.add_child(_champion_label)
	var energy := _labelled_bar(UiTheme.ENERGY)
	_energy_bar = energy[0]
	_energy_text = energy[1]
	condition_column.add_child(energy[2])
	var bond := _labelled_bar(UiTheme.HAPPINESS)
	_happiness_bar = bond[0]
	_happiness_text = bond[1]
	condition_column.add_child(bond[2])
	condition.add_child(condition_column)
	row.add_child(condition)
	var menu := UiKit.button("☰", _open_menu, "", 64)
	menu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(menu)
	return row


## [bar, text label, container] — bars always carry a word and a number.
func _labelled_bar(color: Color) -> Array:
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 18)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := UiKit.bar(0, 100, color, 18)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(bar)
	var text := Label.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 8
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", UiTheme.fs(14))
	text.add_theme_constant_override("outline_size", 5)
	text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	stack.add_child(text)
	return [bar, text, stack]


func _build_objective() -> Control:
	_objective_card = UiKit.panel("ChipPanel")
	_objective_card.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.82), 14, UiTheme.ACCENT_DARK, 1, 10))
	_objective_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_objective_card.custom_minimum_size.x = 380
	_objective_card.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.add_press_feedback(_objective_card)
	_objective_card.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			var objective := QuestLog.current()
			if not objective.is_empty():
				Sfx.play("ui_click")
				objective_requested.emit(objective["station"]))
	var column := UiKit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_card.add_child(column)
	_objective_text = UiKit.label("")
	_objective_text.add_theme_color_override("font_color", UiTheme.ACCENT)
	_objective_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_objective_text)
	_objective_hint = UiKit.label("", "DimLabel", true)
	_objective_hint.custom_minimum_size.x = 360
	_objective_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_objective_hint)
	return _objective_card


func refresh() -> void:
	var profile := Game.profile
	var champion := Game.champion()
	_lodge_label.text = profile.lodge_title()
	_level_label.text = "Keeper Lv %d" % profile.level
	_xp_bar.max_value = OwnerProfile.xp_to_next(profile.level)
	_xp_bar.value = profile.xp
	_animate_coins(profile.coins)
	_mentors.text = "Mentors %d/%d" % [profile.active_trainers.size(), profile.trainer_slots()]
	_champion_label.text = "%s%s" % [champion.name, "  · knocked out" if champion.knocked_out else ""]
	_energy_bar.value = champion.energy
	_energy_text.text = "Energy %d" % roundi(champion.energy)
	_happiness_bar.value = champion.happiness
	_happiness_text.text = "Bond %d · %s" % [roundi(champion.happiness), champion.mood_name()]
	var objective := QuestLog.current()
	_objective_card.visible = not objective.is_empty()
	if not objective.is_empty():
		var progress := QuestLog.progress()
		_objective_text.text = "◆ %s" % QuestLog.text(objective)
		_objective_hint.text = "%s  (%d/%d) — tap to go there" % [QuestLog.text(objective, "hint"), progress.x, progress.y]
	_build_nav()


func _build_nav() -> void:
	UiKit.clear(_nav_row)
	for entry: Array in NAV:
		if not Game.is_flag_set(entry[2]):
			continue
		var panel_id: String = entry[0]
		var button := UiKit.button(entry[1], func() -> void: panel_requested.emit(panel_id), "", 118)
		var badge := ""
		if is_new(panel_id):
			badge = "NEW"
		elif needs_attention(panel_id):
			badge = "●"
		if not badge.is_empty():
			var tag := Label.new()
			tag.text = badge
			tag.add_theme_font_size_override("font_size", UiTheme.fs(13 if badge == "NEW" else 18))
			tag.add_theme_color_override("font_color", Color("1d1609") if badge == "NEW" else UiTheme.ACCENT)
			if badge == "NEW":
				tag.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.ACCENT, 8, Color.TRANSPARENT, 0, 3))
			tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			tag.position = Vector2(-6, -8)
			tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(tag)
		_nav_row.add_child(button)


## Coins count up/down so every reward is felt (instant feedback).
func _animate_coins(target: int) -> void:
	if _shown_coins < 0.0 or Settings.get_value("reduce_motion"):
		_shown_coins = target
		_coins.text = "◉ %d" % target
		return
	if roundi(_shown_coins) == target:
		return
	if _coin_tween != null:
		_coin_tween.kill()
	if target > _shown_coins:
		Sfx.play("coins")
	_coin_tween = create_tween()
	_coin_tween.tween_method(func(value: float) -> void:
		_shown_coins = value
		_coins.text = "◉ %d" % roundi(value), _shown_coins, float(target), 0.6)


func _open_menu() -> void:
	var content := UiKit.modal(self, "Lodge", 560)
	var column := UiKit.vbox(12)
	content.add_child(column)
	column.add_child(UiKit.label("Your journey is saved automatically.", "DimLabel"))
	column.add_child(UiKit.button("Journal — recent events", func() -> void:
		UiKit.close_modal(content)
		_open_journal()))
	column.add_child(UiKit.button("Guide — how things work", func() -> void:
		UiKit.close_modal(content)
		panel_requested.emit("codex")))
	column.add_child(UiKit.button("Settings", func() -> void:
		UiKit.close_modal(content)
		SettingsPanel.open(self, false)))
	column.add_child(UiKit.button("Save & return to title", func() -> void:
		Game.save()
		UiKit.close_modal(content)
		Router.go("title")))
	column.add_child(UiKit.primary_button("Back to the lodge", func() -> void: UiKit.close_modal(content)))


## Notification history (cognitive accessibility: nothing is missed).
func _open_journal() -> void:
	var content := UiKit.modal(self, "Journal", 640)
	var list := UiKit.vbox(8)
	var scroller := UiKit.scroll(list)
	scroller.custom_minimum_size.y = 380
	content.add_child(scroller)
	if Notify.history.is_empty():
		list.add_child(UiKit.label("Nothing has happened yet today.", "DimLabel"))
	for entry: Dictionary in Notify.history:
		var line := UiKit.label("• " + str(entry["text"]), "", true)
		line.add_theme_color_override("font_color", Color.html(str(entry["color"])))
		list.add_child(line)
	content.add_child(UiKit.primary_button("Close", func() -> void: UiKit.close_modal(content)))
