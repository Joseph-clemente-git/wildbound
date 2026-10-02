extends Node3D
## Opponent Preview: after choosing a fight, see who stands across the ring,
## why the fight matters and where it happens — enough to decide how to
## prepare, never the opponent's exact numbers or a win chance.
## Params: {"trial": id}

const BAND_FILL := {"Very Low": 0.2, "Low": 0.4, "Medium": 0.6, "High": 0.8, "Very High": 1.0,
		"Short": 0.33, "Long": 1.0}
const FORCE_FIELDS: Array[String] = ["Strength", "Defense", "Mobility", "Range"]

var trial: TrialData
var opponent: OpponentData
var report: ScoutingReport
var _root: Control


func _ready() -> void:
	if not Game.is_active():
		Router.go("title")
		return
	trial = Content.trial(Router.params.get("trial", ""))
	if trial == null or not ChallengeBoard.can_select(trial):
		_return_to_journey()
		return
	opponent = Content.opponent(trial.opponent_id)
	report = ScoutingReport.for_opponent(opponent)
	Router.back_requested.connect(_back)
	_backdrop()
	_build_ui()


## A fight that cannot be chosen (stale link, locked by a load) goes back to
## the board once the transition that brought us here has finished.
func _return_to_journey() -> void:
	while Router.is_transitioning():
		await get_tree().process_frame
	Router.go("journey")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back()


func _back() -> void:
	Router.go("journey", {"region": trial.region_id})


func _continue() -> void:
	Sfx.play("ui_confirm")
	Router.go("champion_select", {"trial": trial.id})


func _backdrop() -> void:
	FightStage.backdrop(self, Content.arena(trial.arena_id))
	var rival := FightStage.opponent_figure(opponent)
	rival.rotation.y = deg_to_rad(165)  # face the Keeper
	add_child(rival)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.4, 4.2)
	# Shift the frame so the opponent stands to the right of the sheet.
	camera.h_offset = -1.9
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	Sfx.play_ambient()


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
	column.add_child(UiKit.label("OPPONENT PREVIEW · " + trial.challenge_type_name().to_upper(), "DimLabel"))
	column.add_child(UiKit.heading(trial.display_name))
	var body := UiKit.vbox(12)
	column.add_child(UiKit.scroll(body))
	body.add_child(UiKit.label(trial.reason if not trial.reason.is_empty() else trial.description, "", true))
	_opponent_card(body)
	_watch_card(body)
	_arena_card(body)
	var first_bonus := "" if Game.is_flag_set(trial.cleared_flag()) else " (+%d first victory)" % trial.first_clear_coins
	column.add_child(UiKit.label("Energy %d · Reward ◉ %d%s" % [trial.energy_cost, trial.coins, first_bonus], "DimLabel", true))
	var row := UiKit.hbox(12)
	row.add_child(UiKit.button("Back", _back, "", 150))
	row.add_child(UiKit.spacer(false))
	var choose := UiKit.primary_button("Choose Champion", _continue, 260)
	choose.name = "Continue"
	row.add_child(choose)
	column.add_child(row)


func _card(parent: VBoxContainer, title: String) -> VBoxContainer:
	var panel := UiKit.panel("CardPanel")
	var column := UiKit.vbox(6)
	panel.add_child(column)
	var heading := UiKit.label(title, "", true)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	heading.add_theme_font_size_override("font_size", UiTheme.fs(24))
	column.add_child(heading)
	parent.add_child(panel)
	return column


func _opponent_card(body: VBoxContainer) -> void:
	var card := _card(body, "%s — %s" % [report.name, report.title])
	if not report.bio.is_empty():
		card.add_child(UiKit.label(report.bio, "DimLabel", true))
	var scouting := UiKit.grid(2, 14)
	scouting.name = "Scouting"
	var fields := report.fields()
	for key: String in fields:
		if key == "Opponent":
			continue
		var cell := UiKit.stat_row(key, fields[key], BAND_FILL.get(fields[key], 0.66) if FORCE_FIELDS.has(key) else -1.0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scouting.add_child(cell)
	card.add_child(scouting)
	if not opponent.intro_line.is_empty():
		card.add_child(UiKit.label(opponent.intro_line, "DimLabel", true))


func _watch_card(body: VBoxContainer) -> void:
	var card := _card(body, "What to watch for")
	card.name = "Watch"
	_tag_list(card, "Threats", report.threats, UiTheme.BAD, "Nothing that stands out.")
	_tag_list(card, "Openings", report.openings, UiTheme.GOOD, "No obvious weaknesses — look for them in the fight.")


func _tag_list(card: VBoxContainer, title: String, items: PackedStringArray, color: Color, empty_text: String) -> void:
	var label := UiKit.label(title)
	label.add_theme_color_override("font_color", color)
	card.add_child(label)
	card.add_child(UiKit.label(("• " + "\n• ".join(items)) if not items.is_empty() else empty_text, "", true))


func _arena_card(body: VBoxContainer) -> void:
	var arena := Content.arena(trial.arena_id)
	var card := _card(body, "Arena: " + arena.display_name)
	card.add_child(UiKit.label(arena.description, "DimLabel", true))
	card.add_child(UiKit.label("• " + "\n• ".join(arena.features()), "", true))
