class_name DialogueBox
extends Control
## Story dialogue overlay: speaker, typewriter text, tap to continue.
## Emits `beat_started` so scenes can move cameras, and `finished` at the end.

signal beat_started(beat: Dictionary)
signal finished

const CHARS_PER_SECOND := 55.0

var _beats: Array = []
var _index := -1
var _panel: PanelContainer
var _speaker: Label
var _text: RichTextLabel
var _continue: Label
var _name_row: HBoxContainer
var _name_edit: LineEdit
var _tween: Tween
var _waiting_for_name := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	var safe := UiKit.safe_area(20)
	add_child(safe)
	var column := UiKit.vbox(10)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	var top := UiKit.hbox()
	top.add_child(UiKit.spacer(false))
	var skip := UiKit.button("Skip ▸▸", _skip_all, "FlatButton")
	top.add_child(skip)
	column.add_child(top)
	column.add_child(UiKit.spacer())
	_panel = UiKit.panel("SheetPanel")
	_panel.custom_minimum_size = Vector2(0, 190)
	column.add_child(_panel)
	var inner := UiKit.vbox(8)
	_panel.add_child(inner)
	_speaker = UiKit.label("", "HeadingLabel")
	inner.add_child(_speaker)
	_text = UiKit.rich("")
	_text.add_theme_font_size_override("normal_font_size", 24)
	inner.add_child(_text)
	_name_row = UiKit.hbox(12)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(320, UiTheme.TOUCH_MIN)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _confirm_name())
	_name_row.add_child(_name_edit)
	_name_row.add_child(UiKit.primary_button("That's the name", _confirm_name))
	_name_row.visible = false
	inner.add_child(_name_row)
	_continue = UiKit.label("Tap to continue ▾", "DimLabel")
	_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner.add_child(_continue)


func play(beats: Array) -> void:
	_beats = beats.duplicate(true)  # story data is read-only
	_index = -1
	visible = true
	_advance()


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		accept_event()
		_on_tap()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.pressed and (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER] \
			and not _waiting_for_name:
		_on_tap()


func _on_tap() -> void:
	if _waiting_for_name:
		return
	if _text.visible_ratio < 1.0:
		_finish_reveal()
	else:
		Sfx.play("ui_click", 0.02)
		_advance()


func _advance() -> void:
	_index += 1
	if _index >= _beats.size():
		visible = false
		finished.emit()
		return
	var beat: Dictionary = _beats[_index]
	var speaker: String = beat.get("speaker", "narrator")
	var champion := Game.champion()
	_speaker.text = StoryEvents.speaker_name(speaker, champion.name if champion else "", Game.profile.keeper_name if Game.profile else "")
	_speaker.add_theme_color_override("font_color", StoryEvents.speaker_color(speaker))
	_speaker.visible = not _speaker.text.is_empty()
	var body := StoryDirector.format(str(beat.get("text", "")))
	_text.text = ("[i]%s[/i]" % body) if speaker == "narrator" or body.begins_with("*") else body
	_text.visible_ratio = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(body.length() / CHARS_PER_SECOND, 0.2))
	_tween.tween_callback(_finish_reveal)
	_continue.visible = false
	_name_row.visible = false
	beat_started.emit(beat)


func _finish_reveal() -> void:
	if _tween != null:
		_tween.kill()
	_text.visible_ratio = 1.0
	var beat: Dictionary = _beats[_index] if _index >= 0 and _index < _beats.size() else {}
	var action: String = beat.get("action", "")
	if action == "name_champion" and not _waiting_for_name:
		_waiting_for_name = true
		_name_row.visible = true
		_name_edit.text = Game.champion().name
		_name_edit.grab_focus()
		_continue.visible = false
		return
	_continue.visible = not _waiting_for_name
	if not action.is_empty() and action != "name_champion" and not beat.get("_applied", false):
		beat["_applied"] = true
		StoryDirector.apply(action)


func _confirm_name() -> void:
	if not _waiting_for_name:
		return
	StoryDirector.rename_champion(_name_edit.text)
	_waiting_for_name = false
	_name_row.visible = false
	Sfx.play("ui_confirm")
	_advance()


func _skip_all() -> void:
	# Skipping still applies every remaining action so the story state stays valid.
	for i in range(maxi(_index, 0), _beats.size()):
		var beat: Dictionary = _beats[i]
		var action: String = beat.get("action", "")
		if not action.is_empty() and action != "name_champion" and not beat.get("_applied", false):
			beat["_applied"] = true
			StoryDirector.apply(action)
	_waiting_for_name = false
	_index = _beats.size() - 1
	_advance()
