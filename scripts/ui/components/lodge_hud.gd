class_name LodgeHud
extends Control
## Lodge overlay: lodge reputation, coins, mentors, champion condition, the
## current objective and short navigation. Systems appear as they are
## introduced by the story (story §18, §25).

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
var _xp_bar: ProgressBar
var _coins: Label
var _mentors: Label
var _champion_label: Label
var _energy_bar: ProgressBar
var _happiness_bar: ProgressBar
var _objective_card: PanelContainer
var _objective_text: Label
var _objective_hint: Label
var _nav_row: HBoxContainer


static func is_panel_unlocked(panel_id: String) -> bool:
	for entry: Array in NAV:
		if entry[0] == panel_id:
			return Game.is_flag_set(entry[2])
	return true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	var safe := UiKit.safe_area(16)
	add_child(safe)
	var column := UiKit.vbox(10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	column.add_child(_build_top_bar())
	column.add_child(_build_objective())
	column.add_child(UiKit.spacer())
	_nav_row = UiKit.hbox(10)
	_nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_nav_row)


func _build_top_bar() -> Control:
	var bar := UiKit.panel("CardPanel")
	bar.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.88), 16, UiTheme.BORDER, 1, 10))
	var row := UiKit.hbox(22)
	bar.add_child(row)
	var lodge := UiKit.vbox(4)
	lodge.custom_minimum_size.x = 250
	_lodge_label = UiKit.label("")
	lodge.add_child(_lodge_label)
	_xp_bar = UiKit.bar(0, 1, UiTheme.ACCENT, 8)
	lodge.add_child(_xp_bar)
	row.add_child(lodge)
	_coins = UiKit.label("")
	_coins.add_theme_color_override("font_color", UiTheme.ACCENT)
	_coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_coins)
	_mentors = UiKit.label("")
	_mentors.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_mentors)
	row.add_child(UiKit.spacer(false))
	var condition := UiKit.vbox(4)
	condition.custom_minimum_size.x = 240
	_champion_label = UiKit.label("")
	condition.add_child(_champion_label)
	var energy_row := UiKit.hbox(6)
	energy_row.add_child(UiKit.label("Energy", "DimLabel"))
	_energy_bar = UiKit.bar(0, 100, UiTheme.ENERGY, 10)
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_row.add_child(_energy_bar)
	condition.add_child(energy_row)
	var mood_row := UiKit.hbox(6)
	mood_row.add_child(UiKit.label("Bond  ", "DimLabel"))
	_happiness_bar = UiKit.bar(0, 100, UiTheme.HAPPINESS, 10)
	_happiness_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mood_row.add_child(_happiness_bar)
	condition.add_child(mood_row)
	row.add_child(condition)
	var menu := UiKit.button("☰", _open_menu, "", 64)
	row.add_child(menu)
	return bar


func _build_objective() -> Control:
	_objective_card = UiKit.panel("CardPanel")
	_objective_card.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.82), 14, UiTheme.ACCENT_DARK, 1, 12))
	_objective_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_objective_card.custom_minimum_size.x = 420
	_objective_card.mouse_filter = Control.MOUSE_FILTER_STOP
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
	column.add_child(_objective_text)
	_objective_hint = UiKit.label("", "DimLabel", true)
	_objective_hint.custom_minimum_size.x = 400
	column.add_child(_objective_hint)
	return _objective_card


func refresh() -> void:
	var profile := Game.profile
	var champion := Game.champion()
	_lodge_label.text = "%s · Keeper Lv %d" % [profile.lodge_title(), profile.level]
	_xp_bar.max_value = OwnerProfile.xp_to_next(profile.level)
	_xp_bar.value = profile.xp
	_coins.text = "◉ %d" % profile.coins
	_mentors.text = "Mentors %d/%d" % [profile.active_trainers.size(), profile.trainer_slots()]
	_champion_label.text = "%s%s" % [champion.name, "  (knocked out)" if champion.knocked_out else ""]
	_energy_bar.value = champion.energy
	_happiness_bar.value = champion.happiness
	var objective := QuestLog.current()
	_objective_card.visible = not objective.is_empty()
	if not objective.is_empty():
		var progress := QuestLog.progress()
		_objective_text.text = "◆ %s" % QuestLog.text(objective)
		_objective_hint.text = "%s   (%d/%d)" % [QuestLog.text(objective, "hint"), progress.x, progress.y]
	UiKit.clear(_nav_row)
	for entry: Array in NAV:
		if not Game.is_flag_set(entry[2]):
			continue
		var button := UiKit.button(entry[1], func() -> void: panel_requested.emit(entry[0]), "", 128)
		_nav_row.add_child(button)


func _open_menu() -> void:
	var content := UiKit.modal(self, "Lodge", 520)
	var column := UiKit.vbox(12)
	content.add_child(column)
	column.add_child(UiKit.label("Your journey is saved automatically.", "DimLabel"))
	column.add_child(UiKit.button("Settings", func() -> void:
		UiKit.close_modal(content)
		SettingsPanel.open(self, false)))
	column.add_child(UiKit.button("Save & return to title", func() -> void:
		Game.save()
		UiKit.close_modal(content)
		Router.go("title")))
	column.add_child(UiKit.primary_button("Back to the lodge", func() -> void: UiKit.close_modal(content)))
