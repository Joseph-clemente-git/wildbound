extends Node3D
## Champion Selection: after seeing the opponent, choose which champion
## enters. Shows each champion's readiness — energy, mood, knockouts — and
## its current build. Matchup advice belongs to Battle Preparation.
## Params: {"trial": id, "champion": uid (optional preselection)}

var trial: TrialData
var opponent: OpponentData
var chosen: Champion
var _root: Control
var _list: VBoxContainer
var _status: Label
var _prepare: Button
var _rest: Button
var _figure: CharacterVisual


func _ready() -> void:
	if not Game.is_active():
		Router.go("title")
		return
	trial = Content.trial(Router.params.get("trial", ""))
	if trial == null or not ChallengeBoard.can_select(trial):
		_return_to_journey()
		return
	opponent = Content.opponent(trial.opponent_id)
	chosen = _find(Router.params.get("champion", ""))
	if chosen == null:
		chosen = ChampionSelection.default_choice(trial)
	Router.back_requested.connect(_back)
	FightStage.backdrop(self, Content.arena(trial.arena_id))
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.4, 4.2)
	camera.h_offset = -1.9
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	Sfx.play_ambient()
	_build_ui()
	Game.changed.connect(_refresh)
	_refresh()


func _return_to_journey() -> void:
	while Router.is_transitioning():
		await get_tree().process_frame
	Router.go("journey")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back()


func _back() -> void:
	Router.go("fight_preview", {"trial": trial.id})


func _find(uid: String) -> Champion:
	for champion in Game.champions:
		if champion.uid == uid:
			return champion
	return null


func pick(uid: String) -> void:
	var champion := _find(uid)
	if champion != null and champion != chosen:
		chosen = champion
		Sfx.play("ui_click")
		_refresh()


func confirm() -> void:
	var reason := ChampionSelection.choose(chosen, trial)
	if not reason.is_empty():
		UiKit.toast(_root, reason, UiTheme.BAD)
		return
	Sfx.play("ui_confirm")
	Router.go("battle_prep", {"trial": trial.id, "champion": chosen.uid})


## The lodge's Rest Area cares for the selected champion, so select the one
## that needs it first.
func rest_chosen() -> void:
	Game.select_champion(chosen.uid)
	Router.go("lodge", {"panel": "recovery"})


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_root)
	var sheet := UiKit.panel("SheetPanel")
	sheet.anchor_right = 0.58
	sheet.anchor_bottom = 1.0
	var insets := UiKit.safe_insets()
	sheet.offset_left = 16 + insets.x
	sheet.offset_top = 16 + insets.y
	sheet.offset_bottom = -16 - insets.w
	_root.add_child(sheet)
	var column := UiKit.vbox(10)
	sheet.add_child(column)
	column.add_child(UiKit.label("CHOOSE CHAMPION · %s" % trial.display_name.to_upper(), "DimLabel", true))
	column.add_child(UiKit.heading("Who faces %s?" % opponent.display_name))
	_list = UiKit.vbox(12)
	column.add_child(UiKit.scroll(_list))
	_status = UiKit.label("", "", true)
	column.add_child(_status)
	var row := UiKit.hbox(12)
	row.add_child(UiKit.button("Back", _back, "", 150))
	_rest = UiKit.button("Rest at the lodge", rest_chosen)
	row.add_child(_rest)
	row.add_child(UiKit.spacer(false))
	_prepare = UiKit.primary_button("Prepare", confirm, 240)
	_prepare.name = "Prepare"
	row.add_child(_prepare)
	column.add_child(row)


func _refresh() -> void:
	if _list == null or chosen == null:
		return
	UiKit.clear(_list)
	for champion in ChampionSelection.candidates(trial):
		_list.add_child(_champion_card(champion))
	var reason := ChampionSelection.blocker(chosen, trial)
	_status.text = "%s is ready." % chosen.name if reason.is_empty() else reason
	_status.add_theme_color_override("font_color", UiTheme.GOOD if reason.is_empty() else UiTheme.BAD)
	_prepare.text = "Prepare " + chosen.name
	_prepare.disabled = not reason.is_empty()
	_rest.visible = not reason.is_empty()
	_show_figure()


func _champion_card(champion: Champion) -> Control:
	var selected := champion == chosen
	var panel := UiKit.panel("CardPanel")
	panel.name = "Champion_" + champion.uid
	if selected:
		panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_LIGHT, 14, UiTheme.ACCENT, 3, 14))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS  # taps select, drags still scroll
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed)
		if pressed:
			pick(champion.uid))
	var column := UiKit.vbox(6)
	panel.add_child(column)
	var heading := UiKit.label("%s · Level %d · %s" % [champion.name, champion.level, champion.capability_name()], "", true)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	heading.add_theme_font_size_override("font_size", UiTheme.fs(24))
	column.add_child(heading)
	var animal := champion.data()
	column.add_child(UiKit.label("%s · %s · %s" % [animal.display_name,
			GameEnums.MOVEMENT_TYPE_NAMES[animal.movement_type], _build_text(champion)], "DimLabel", true))
	column.add_child(UiKit.stat_row("Energy", "%d / %d" % [roundi(champion.energy), roundi(champion.max_energy())],
			champion.energy / champion.max_energy(), UiTheme.ENERGY))
	column.add_child(UiKit.stat_row("Mood", champion.mood_name(), champion.happiness / champion.max_happiness(),
			UiTheme.HAPPINESS))
	var reason := ChampionSelection.blocker(champion, trial)
	var state := UiKit.label("Ready" if reason.is_empty() else reason, "", true)
	state.add_theme_color_override("font_color", UiTheme.GOOD if reason.is_empty() else UiTheme.BAD)
	column.add_child(state)
	var notes := ChampionSelection.notes(champion, trial)
	if not notes.is_empty():
		column.add_child(UiKit.label(" · ".join(notes), "DimLabel", true))
	_ignore_mouse(column)
	return panel


## Lets taps anywhere on a card reach the card itself.
static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


static func _build_text(champion: Champion) -> String:
	var weapon := Content.weapon(champion.weapon_id)
	var armor := Content.armor(champion.armor_id)
	var ability := Content.ability(champion.equipped_ability)
	return "%s · %s armor · %s" % [weapon.display_name if weapon != null else "No weapon",
			GameEnums.ARMOR_WEIGHT_NAMES[armor.weight_class] if armor != null else "No",
			ability.display_name if ability != null else "No Aether Art"]


func _show_figure() -> void:
	if _figure != null and _figure.get_meta("uid", "") == chosen.uid:
		return
	if _figure != null:
		_figure.queue_free()
	_figure = FightStage.champion_figure(chosen)
	_figure.set_meta("uid", chosen.uid)
	_figure.rotation.y = deg_to_rad(165)
	add_child(_figure)
