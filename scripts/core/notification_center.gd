extends Node
## Notification queue (autoload "Notify"), following the ui-ux-game
## NotificationQueue pattern: stacked toasts at the top of the screen,
## at most a few visible, duplicates grouped (×2), priority colours, and a
## history the player can review later (cognitive accessibility).

const MAX_VISIBLE := 3
const SECONDS := 2.6
const HISTORY_LIMIT := 40

var history: Array[Dictionary] = []  # {text, color, time}

var _layer: CanvasLayer
var _stack: VBoxContainer
var _entries: Dictionary = {}  # text -> {panel, label, count, timer}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	var anchor := MarginContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	anchor.grow_horizontal = Control.GROW_DIRECTION_BOTH
	anchor.add_theme_constant_override("margin_top", 92)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(anchor)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_stack)


func push(text: String, color: Color = Color(0, 0, 0, 0), seconds: float = SECONDS) -> void:
	if color.a == 0.0:
		color = UiTheme.TEXT
	history.push_front({"text": text, "color": color.to_html(), "time": Time.get_unix_time_from_system()})
	while history.size() > HISTORY_LIMIT:
		history.pop_back()
	if _entries.has(text):
		var entry: Dictionary = _entries[text]
		entry["count"] += 1
		(entry["label"] as Label).text = "%s  ×%d" % [text, entry["count"]]
		entry["timer"] = seconds
		_pop(entry["panel"])
		return
	while _stack.get_child_count() >= MAX_VISIBLE:
		var oldest := _stack.get_child(0)
		_entries.erase(oldest.get_meta("text"))
		oldest.free()
	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.95), 14, color.darkened(0.2), 2, 12))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("text", text)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	_stack.add_child(panel)
	_entries[text] = {"panel": panel, "label": label, "count": 1, "timer": seconds}
	_pop(panel)


func clear() -> void:
	for child in _stack.get_children():
		child.free()
	_entries.clear()


func _process(delta: float) -> void:
	for text: String in _entries.keys():
		var entry: Dictionary = _entries[text]
		entry["timer"] -= delta
		if entry["timer"] <= 0.0:
			_entries.erase(text)
			var panel: Control = entry["panel"]
			var tween := panel.create_tween()
			tween.tween_property(panel, "modulate:a", 0.0, 0.3)
			tween.tween_callback(panel.queue_free)


func _pop(panel: Control) -> void:
	if Settings.get_value("reduce_motion"):
		return
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
