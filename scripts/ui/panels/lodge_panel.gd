class_name LodgePanel
extends Control
## Base for lodge sub-screens: a right-hand sheet with a title, close button
## and a scrolling body. Subclasses implement `build(body)` and call
## `rebuild()` after changes. The panel refreshes when the game changes.

signal close_requested

const SHEET_WIDTH := 0.64

var host: PanelHost
var panel_id := ""
var options: Dictionary = {}
var title := "Panel"
var body: VBoxContainer
var _title_label: Label
var _scroll: ScrollContainer
var _tabs_row: HBoxContainer
var _rebuild_queued := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			close_requested.emit())
	add_child(dim)
	var sheet := UiKit.panel("SheetPanel")
	sheet.anchor_left = 1.0 - SHEET_WIDTH
	sheet.anchor_right = 1.0
	sheet.anchor_bottom = 1.0
	var insets := UiKit.safe_insets()
	sheet.offset_left = 0
	sheet.offset_top = 12 + insets.y
	sheet.offset_right = -12 - insets.z
	sheet.offset_bottom = -12 - insets.w
	add_child(sheet)
	var column := UiKit.vbox(12)
	sheet.add_child(column)
	var header := UiKit.hbox(12)
	_title_label = UiKit.heading(title)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	header.add_child(UiKit.button("✕", func() -> void: close_requested.emit(), "FlatButton", 64))
	column.add_child(header)
	_tabs_row = UiKit.hbox(8)
	_tabs_row.visible = false
	column.add_child(_tabs_row)
	body = UiKit.vbox(14)
	_scroll = UiKit.scroll(body)
	column.add_child(_scroll)
	Game.changed.connect(queue_rebuild)
	if not Settings.get_value("reduce_motion"):
		sheet.position.x += 60
		sheet.modulate.a = 0.0
		var tween := create_tween().set_parallel()
		tween.tween_property(sheet, "modulate:a", 1.0, 0.16)
		tween.tween_property(sheet, "position:x", sheet.position.x - 60, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rebuild()


func set_title(text: String) -> void:
	title = text
	if _title_label != null:
		_title_label.text = text


## Tabs shown under the title: [[label, key], ...]
func set_tabs(tabs: Array, current: String, on_select: Callable) -> void:
	UiKit.clear(_tabs_row)
	_tabs_row.visible = not tabs.is_empty()
	for tab: Array in tabs:
		var button := UiKit.button(tab[0], on_select.bind(tab[1]), "TabButtonSelected" if tab[1] == current else "TabButton")
		button.custom_minimum_size.y = 52
		_tabs_row.add_child(button)


func queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	# Deferred method calls (unlike lambdas) are dropped if the panel is freed first.
	_run_queued_rebuild.call_deferred()


func _run_queued_rebuild() -> void:
	_rebuild_queued = false
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	var scroll_value := _scroll.scroll_vertical
	UiKit.clear(body)
	build(body)
	_scroll.set_deferred("scroll_vertical", scroll_value)


## Override in subclasses.
func build(_container: VBoxContainer) -> void:
	pass


func toast(text: String, color: Color = UiTheme.TEXT) -> void:
	UiKit.toast(host if host != null else self, text, color)


## Small helper: a card with a heading line and optional subtitle.
func card(heading_text: String, subtitle: String = "") -> VBoxContainer:
	var panel := UiKit.panel("CardPanel")
	var column := UiKit.vbox(8)
	panel.add_child(column)
	if not heading_text.is_empty():
		var heading := UiKit.label(heading_text)
		heading.add_theme_font_size_override("font_size", UiTheme.fs(24))
		heading.add_theme_color_override("font_color", UiTheme.ACCENT)
		column.add_child(heading)
	if not subtitle.is_empty():
		column.add_child(UiKit.label(subtitle, "DimLabel", true))
	body.add_child(panel)
	return column
