class_name SkillNetworkView
extends Control
## Draws a SkillNetwork as a pannable, zoomable graph: nodes in columns by
## Skill Matrix layer, curved links from what is needed to what it opens.
## Drag to pan, pinch or wheel to zoom; tap a node to select it. Selecting a
## node lights up its links and fades everything unrelated.
##
## Text inside the graph is drawn at fixed sizes and the accessibility text
## scale multiplies the zoom instead, so larger text never breaks the layout.

signal node_selected(id: String)

const NODE_SIZE := Vector2(236, 70)
const COLUMN_GAP := 128.0
const ROW_GAP := 86.0
const MARGIN := 36.0
## Room above the first row for the column headings.
const HEADER := 58.0
const MIN_ZOOM := 0.35
const MAX_ZOOM := 1.4
## A press that moved further than this was a pan, not a tap.
const TAP_SLOP := 14.0

var network: SkillNetwork
var selected := ""
var zoom := 0.85

var _world: Control
var _edges: Control
## Drawn above the nodes: the rank each lit link asks for.
var _labels: Control
var _buttons: Dictionary = {}
var _touches: Dictionary = {}
var _pinch_distance := 0.0
var _press_travel := 0.0
var _placed := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_world = Control.new()
	_world.name = "World"
	_world.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_world)
	_edges = Control.new()
	_edges.name = "Links"
	_edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edges.draw.connect(_draw_links)
	_world.add_child(_edges)
	_labels = Control.new()
	_labels.name = "LinkLabels"
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.draw.connect(_draw_link_labels)
	_world.add_child(_labels)
	resized.connect(_on_resized)
	if network != null:
		_populate()


func set_network(value: SkillNetwork) -> void:
	network = value
	if is_inside_tree():
		_populate()


func select(id: String, center: bool = false) -> void:
	if network == null or not network.nodes.has(id):
		return
	selected = id
	_refresh_highlight()
	if center:
		focus_on(id)
	node_selected.emit(id)


static func node_position(entry: Dictionary) -> Vector2:
	return Vector2(MARGIN + int(entry["column"]) * (NODE_SIZE.x + COLUMN_GAP),
			HEADER + MARGIN + float(entry["row"]) * ROW_GAP)


## World-space rectangle holding every node.
func content_rect() -> Rect2:
	var rect := Rect2()
	var first := true
	for id: String in network.order:
		var node_rect := Rect2(node_position(network.nodes[id]), NODE_SIZE)
		rect = node_rect if first else rect.merge(node_rect)
		first = false
	return Rect2(Vector2.ZERO, rect.end + Vector2(MARGIN, MARGIN))


# --- Camera ------------------------------------------------------------------------

## Zoom multiplier from the accessibility text scale.
static func text_zoom() -> float:
	return maxf(UiTheme.text_scale, 1.0)


func set_zoom(value: float, pivot: Vector2 = Vector2(-1, -1)) -> void:
	if pivot.x < 0.0:
		pivot = size * 0.5
	var world_point := (pivot - _world.position) / zoom
	zoom = clampf(value, MIN_ZOOM, MAX_ZOOM * text_zoom())
	_world.scale = Vector2(zoom, zoom)
	_world.position = pivot - world_point * zoom
	_clamp()


func zoom_by(factor: float) -> void:
	set_zoom(zoom * factor)


## Shows the whole network.
func fit() -> void:
	var rect := content_rect()
	if rect.size.x <= 0.0 or size.x <= 0.0:
		return
	zoom = clampf(minf(size.x / rect.size.x, size.y / rect.size.y), MIN_ZOOM, MAX_ZOOM * text_zoom())
	_world.scale = Vector2(zoom, zoom)
	_world.position = (size - rect.size * zoom) * 0.5
	_clamp()


## Zooms and centres on a node and everything it links to.
func frame(id: String) -> void:
	if not network.nodes.has(id) or size.x <= 0.0:
		return
	var entry: Dictionary = network.nodes[id]
	var rect := Rect2(node_position(entry), NODE_SIZE)
	for other: String in entry["opens"]:
		rect = rect.merge(Rect2(node_position(network.nodes[other]), NODE_SIZE))
	for need: Dictionary in entry["needs"]:
		rect = rect.merge(Rect2(node_position(network.nodes[need["id"]]), NODE_SIZE))
	rect = rect.grow(MARGIN)
	zoom = clampf(minf(size.x / rect.size.x, size.y / rect.size.y), 0.6 * text_zoom(), text_zoom())
	_world.scale = Vector2(zoom, zoom)
	_world.position = size * 0.5 - rect.get_center() * zoom
	_clamp()


func focus_on(id: String) -> void:
	if not network.nodes.has(id):
		return
	var center := node_position(network.nodes[id]) + NODE_SIZE * 0.5
	_world.position = size * 0.5 - center * zoom
	_clamp()


func camera() -> Dictionary:
	return {"zoom": zoom, "position": _world.position}


func restore_camera(state: Dictionary) -> void:
	zoom = float(state.get("zoom", zoom))
	_world.scale = Vector2(zoom, zoom)
	_world.position = state.get("position", _world.position)
	_placed = true
	_clamp()


## Keeps at least part of the network on screen.
func _clamp() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or network == null:
		return
	var extent := content_rect().size * zoom
	var keep := minf(160.0, minf(size.x, size.y) * 0.4)
	_world.position.x = clampf(_world.position.x, keep - extent.x, size.x - keep)
	_world.position.y = clampf(_world.position.y, keep - extent.y, size.y - keep)


func _on_resized() -> void:
	if network == null or size.x <= 0.0:
		return
	if not _placed:
		_placed = true
		if not selected.is_empty():
			frame(selected)
		else:
			fit()
	else:
		_clamp()


# --- Input -------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
			if _touches.size() == 1:
				_press_travel = 0.0
		else:
			_touches.erase(touch.index)
		_pinch_distance = _touch_spread()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touches[drag.index] = drag.position
		if _touches.size() >= 2:
			var spread := _touch_spread()
			if _pinch_distance > 0.0 and spread > 0.0:
				set_zoom(zoom * spread / _pinch_distance, _touch_center())
			_pinch_distance = spread
			_press_travel = INF
		else:
			_press_travel += drag.relative.length()
			_world.position += drag.relative
			_clamp()
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom * 1.1, mouse.position)
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom / 1.1, mouse.position)
			accept_event()
	elif event is InputEventMagnifyGesture:
		set_zoom(zoom * (event as InputEventMagnifyGesture).factor, (event as InputEventMagnifyGesture).position)
		accept_event()
	elif event is InputEventPanGesture:
		_world.position -= (event as InputEventPanGesture).delta * 12.0
		_clamp()
		accept_event()


func _touch_spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1])


func _touch_center() -> Vector2:
	var points: Array = _touches.values()
	return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


func _on_node_pressed(id: String) -> void:
	if _press_travel > TAP_SLOP:
		return
	Sfx.play("ui_click", 0.02)
	select(id)


# --- Building ----------------------------------------------------------------------

func _populate() -> void:
	for button: Control in _buttons.values():
		button.queue_free()
	_buttons.clear()
	for id: String in network.order:
		var entry: Dictionary = network.nodes[id]
		var button := NetworkNode.new()
		button.entry = entry
		button.name = "Node_" + id.replace(":", "_")
		button.position = node_position(entry)
		button.size = NODE_SIZE
		button.custom_minimum_size = NODE_SIZE
		button.pressed.connect(_on_node_pressed.bind(id))
		_world.add_child(button)
		_buttons[id] = button
	_world.move_child(_labels, -1)
	_world.size = content_rect().size
	_edges.size = _world.size
	_labels.size = _world.size
	_refresh_highlight()


func _related(id: String) -> bool:
	if selected.is_empty() or id == selected:
		return true
	var entry: Dictionary = network.nodes[selected]
	if entry["opens"].has(id):
		return true
	for need: Dictionary in entry["needs"]:
		if need["id"] == id:
			return true
	return false


func _refresh_highlight() -> void:
	for id: String in _buttons:
		var button: NetworkNode = _buttons[id]
		button.selected = id == selected
		button.modulate.a = 1.0 if _related(id) else 0.42
		button.queue_redraw()
	_edges.queue_redraw()
	_labels.queue_redraw()


func button_for(id: String) -> Control:
	return _buttons.get(id)


# --- Drawing -----------------------------------------------------------------------

func _draw_links() -> void:
	if network == null:
		return
	var font := get_theme_font("font", "Label")
	var heading_size := UiTheme.FONT_SMALL
	var columns := {}
	for id: String in network.order:
		columns[int(network.nodes[id]["column"])] = true
	for column: int in columns:
		var x := MARGIN + column * (NODE_SIZE.x + COLUMN_GAP)
		_edges.draw_string(font, Vector2(x + 4, MARGIN + 6), SkillNetwork.COLUMNS[column].to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, NODE_SIZE.x, heading_size, UiTheme.ACCENT_DARK.lightened(0.15))
		_edges.draw_line(Vector2(x, MARGIN + 18), Vector2(x + NODE_SIZE.x, MARGIN + 18),
				Color(UiTheme.BORDER, 0.5), 2.0)
	# Faded links first, then the selection's links on top.
	var lit := _lit_edges()
	for edge: Dictionary in network.edges:
		if not lit.has(edge):
			_draw_link(edge, 0.18 if not selected.is_empty() else 0.5, 2.5)
	for edge: Dictionary in lit:
		_draw_link(edge, 1.0, 4.5)


func _lit_edges() -> Array[Dictionary]:
	var lit: Array[Dictionary] = []
	if network == null or selected.is_empty():
		return lit
	for edge: Dictionary in network.edges:
		if edge["from"] == selected or edge["to"] == selected:
			lit.append(edge)
	return lit


func _draw_link_labels() -> void:
	var font := get_theme_font("font", "Label")
	for edge: Dictionary in _lit_edges():
		_draw_link_label(edge, font)


func _link_points(edge: Dictionary) -> PackedVector2Array:
	var from := node_position(network.nodes[edge["from"]]) + Vector2(NODE_SIZE.x, NODE_SIZE.y * 0.5)
	var to := node_position(network.nodes[edge["to"]]) + Vector2(0, NODE_SIZE.y * 0.5)
	var bend := maxf((to.x - from.x) * 0.5, 50.0)
	var curve := Curve2D.new()
	curve.add_point(from, Vector2.ZERO, Vector2(bend, 0))
	curve.add_point(to, Vector2(-bend, 0), Vector2.ZERO)
	return curve.tessellate(4, 3.0)


func _draw_link(edge: Dictionary, alpha: float, width: float) -> void:
	var color: Color = UiTheme.ACCENT if edge["met"] else UiTheme.TEXT_DIM
	var points := _link_points(edge)
	_edges.draw_polyline(points, Color(color, alpha), width, true)
	# Arrow head into the node that needs it.
	var tip: Vector2 = points[points.size() - 1]
	var head := PackedVector2Array([tip, tip + Vector2(-11, -6), tip + Vector2(-11, 6)])
	_edges.draw_colored_polygon(head, Color(color, alpha))


## The rank a link asks for, in the gap next to the node at the other end
## from the selection, so labels of one node's links never stack.
func _draw_link_label(edge: Dictionary, font: Font) -> void:
	var points := _link_points(edge)
	var at: Vector2 = points[0] if edge["to"] == selected else points[points.size() - 1]
	var text := GameEnums.rank_name(int(edge["need"]))
	var font_size := 16
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var size_box := text_size + Vector2(16, 6)
	var offset := Vector2(10, -size_box.y - 4) if edge["to"] == selected else Vector2(-size_box.x - 14, -size_box.y - 4)
	var box := Rect2(at + offset, size_box)
	_labels.draw_style_box(UiTheme.box(UiTheme.BG, 8, UiTheme.ACCENT if edge["met"] else UiTheme.TEXT_DIM, 1, 0), box)
	_labels.draw_string(font, Vector2(box.position.x + 8, box.position.y + 3 + font.get_ascent(font_size)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.ACCENT if edge["met"] else UiTheme.TEXT_DIM)


## One node: a card with the name, its state in words, rank pips and the
## progress inside the current rank. State is never shown by colour alone.
class NetworkNode extends Button:
	const S := SkillNetwork.State

	var entry: Dictionary
	var selected := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS
		flat = true
		clip_contents = true

	func _ready() -> void:
		tooltip_text = "%s — %s" % [entry["name"], status_text(entry)]
		UiKit.add_press_feedback(self)

	static func status_text(node: Dictionary) -> String:
		var state: int = node["state"]
		var kind: String = node["kind"]
		if kind == "technique":
			return ["Locked", "Needs a mentor", "Ready to learn", "Learned", "Learned"][state]
		if node["rank"] > 0:
			var text := GameEnums.rank_name(node["rank"])
			return text + " · max" if state == S.MASTERED else text
		return ["Locked", "Needs a mentor", "Ready to learn", "Learned", "Learned"][state]

	func _draw() -> void:
		var state: int = entry["state"]
		var bg: Color = UiTheme.PANEL
		var border: Color = UiTheme.ACCENT_DARK
		var width := 2
		match state:
			S.LOCKED:
				bg = UiTheme.PANEL.darkened(0.25)
				border = Color(UiTheme.TEXT_DIM, 0.35)
				width = 1
			S.READY:
				border = UiTheme.AETHER
				width = 3
			S.LEARNED:
				bg = UiTheme.PANEL_LIGHT
				border = UiTheme.ACCENT
			S.MASTERED:
				bg = UiTheme.PANEL_LIGHT
				border = UiTheme.GOOD
				width = 3
		var rect := Rect2(Vector2.ZERO, size)
		if selected:
			draw_style_box(UiTheme.box(Color.TRANSPARENT, 16, UiTheme.TEXT, 3, 0), rect)
			rect = rect.grow(-4)
		draw_style_box(UiTheme.box(bg, 12, border, width, 0), rect)
		var font := get_theme_font("font", "Label")
		var name_size := 20
		var small := 16
		var left := rect.position.x + 14.0
		var text_width := rect.size.x - 28.0
		var name_color: Color = UiTheme.TEXT_DIM if state == S.LOCKED else UiTheme.TEXT
		var top := rect.position.y + 8.0
		if entry["kind"] == "technique":
			var c := Vector2(rect.end.x - 16, top + 10)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]),
					UiTheme.AETHER if state != S.LOCKED else Color(UiTheme.TEXT_DIM, 0.5))
			text_width -= 18.0
		draw_string(font, Vector2(left, top + font.get_ascent(name_size)), entry["name"],
				HORIZONTAL_ALIGNMENT_LEFT, text_width, name_size, name_color)
		var status_color: Color = UiTheme.TEXT_DIM
		if state == S.READY:
			status_color = UiTheme.AETHER
		elif state == S.MASTERED:
			status_color = UiTheme.GOOD
		var status_y := top + font.get_height(name_size) + 2.0 + font.get_ascent(small)
		draw_string(font, Vector2(left, status_y), status_text(entry), HORIZONTAL_ALIGNMENT_LEFT,
				text_width - 70.0, small, status_color)
		if entry["kind"] != "technique":
			_draw_pips(Vector2(rect.end.x - 14.0, status_y - font.get_ascent(small) * 0.35))
		if entry["rank"] > 0 and float(entry["progress"]) > 0.0 and state != S.MASTERED:
			var bar := Rect2(rect.position.x + 10, rect.end.y - 7, (rect.size.x - 20) * float(entry["progress"]), 3)
			draw_rect(bar, UiTheme.ACCENT)

	## Six pips, one per rank; ranks beyond the champion's potential are faint.
	func _draw_pips(right_center: Vector2) -> void:
		var rank: int = entry["rank"]
		var cap: int = entry["cap"]
		for i in range(GameEnums.Rank.MASTER):
			var center := right_center - Vector2((GameEnums.Rank.MASTER - 1 - i) * 10.0, 0)
			var level := i + 1
			if level <= rank:
				draw_circle(center, 3.6, UiTheme.GOOD if entry["state"] == S.MASTERED else UiTheme.ACCENT)
			elif level <= cap:
				draw_arc(center, 3.4, 0.0, TAU, 12, Color(UiTheme.TEXT_DIM, 0.8), 1.2, true)
			else:
				draw_circle(center, 1.6, Color(UiTheme.TEXT_DIM, 0.35))
