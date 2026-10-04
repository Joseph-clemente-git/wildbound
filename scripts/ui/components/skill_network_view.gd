class_name SkillNetworkView
extends Control
## The Aether Weave: draws a SkillNetwork as a carved disc with the champion
## at its hub and the Skill Matrix's layers as rings around it. Prerequisites
## are veins between stones; a vein whose requirement is met carries a flow
## of Aether toward what it opens.
##
## Drag to pan, pinch or wheel to zoom; tap a stone to select it. Selecting a
## stone lights its veins, labels the rank each one asks for and fades
## everything unrelated. Text inside the weave is drawn at fixed sizes and the
## accessibility text scale multiplies the zoom instead, so larger text never
## breaks the layout. Motion (flow, pulses, motes) stops under Reduce motion.

signal node_selected(id: String)

## Ring radii from the hub outward (SkillNetwork.RINGS).
const RADII := [255.0, 445.0, 635.0, 825.0]
const HUB_RADIUS := 88.0
const DISC_RADIUS := 950.0
## A node's button: the stone and its name underneath.
const NODE_SIZE := Vector2(156, 122)
const ORB_CENTER := Vector2(78, 46)
const ORB_RADIUS := 30.0
const MIN_ZOOM := 0.2
const MAX_ZOOM := 1.5
## A press that moved further than this was a pan, not a tap.
const TAP_SLOP := 14.0
const DISC := Color("17201b")
const MOTES := 34

var network: SkillNetwork
var selected := ""
var zoom := 0.85
## Name engraved on the hub's ribbon.
var title := ""
## The part of the view not covered by overlays (view coordinates); framing
## centres content here. Empty = the whole view.
var free_rect := Rect2()

var _world: Control
## Everything still: rim, rings, veins, crest. Redrawn only when something changes.
var _disc: Control
## Everything moving: Aether flowing along lit veins, the crest's wreath.
var _flow: Control
var _labels: Control
var _buttons: Dictionary = {}
## Cached vein polylines in world space, one per edge: {points, lengths, total}.
var _paths: Array[Dictionary] = []
## Cached dash segments for unmet veins, one per edge (pairs of points).
var _dashes_cache: Array[PackedVector2Array] = []
var _touches: Dictionary = {}
var _pinch_distance := 0.0
var _press_travel := 0.0
var _placed := false
var _time := 0.0
var _animate := true


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_animate = not bool(Settings.get_value("reduce_motion"))
	_world = Control.new()
	_world.name = "World"
	_world.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_world)
	_disc = Control.new()
	_disc.name = "Disc"
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.draw.connect(_draw_disc)
	_world.add_child(_disc)
	_flow = Control.new()
	_flow.name = "Flow"
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flow.draw.connect(_draw_flowing)
	_world.add_child(_flow)
	_labels = Control.new()
	_labels.name = "Labels"
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.draw.connect(_draw_labels)
	_world.add_child(_labels)
	resized.connect(_on_resized)
	set_process(_animate)
	if network != null:
		_populate()


func _process(delta: float) -> void:
	_time += delta
	_flow.queue_redraw()
	queue_redraw()
	for id: String in _buttons:
		var state: int = network.nodes[id]["state"]
		if id == selected or state == SkillNetwork.State.READY:
			(_buttons[id] as Control).queue_redraw()


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


static func node_center(entry: Dictionary) -> Vector2:
	return Vector2.from_angle(float(entry["angle"])) * float(RADII[int(entry["ring"])])


## Top-left of a node's button in world space.
static func node_position(entry: Dictionary) -> Vector2:
	return node_center(entry) - ORB_CENTER


func content_rect() -> Rect2:
	return Rect2(-DISC_RADIUS, -DISC_RADIUS, DISC_RADIUS * 2.0, DISC_RADIUS * 2.0)


func button_for(id: String) -> Control:
	return _buttons.get(id)


# --- Camera ------------------------------------------------------------------------

## Zoom multiplier from the accessibility text scale.
static func text_zoom() -> float:
	return maxf(UiTheme.text_scale, 1.0)


func _area() -> Rect2:
	return free_rect if free_rect.has_area() else Rect2(Vector2.ZERO, size)


func set_zoom(value: float, pivot: Vector2 = Vector2(-1, -1)) -> void:
	if pivot.x < 0.0:
		pivot = _area().get_center()
	var world_point := (pivot - _world.position) / zoom
	zoom = clampf(value, MIN_ZOOM, MAX_ZOOM * text_zoom())
	_world.scale = Vector2(zoom, zoom)
	_world.position = pivot - world_point * zoom
	_clamp()
	_zoom_changed()


func zoom_by(factor: float) -> void:
	set_zoom(zoom * factor)


## Shows the whole weave.
func fit() -> void:
	_show(content_rect(), MIN_ZOOM, MAX_ZOOM * text_zoom())


## Zooms and centres on a stone and everything it links to.
func frame(id: String) -> void:
	if not network.nodes.has(id):
		return
	var entry: Dictionary = network.nodes[id]
	var rect := Rect2(node_center(entry), Vector2.ZERO)
	for other: String in entry["opens"]:
		rect = rect.expand(node_center(network.nodes[other]))
	for need: Dictionary in entry["needs"]:
		rect = rect.expand(node_center(network.nodes[need["id"]]))
	_show(rect.grow(ORB_RADIUS + 60.0), 0.6 * text_zoom(), 0.95 * text_zoom())
	_keep_in_view(id)


func _show(rect: Rect2, low: float, high: float) -> void:
	var area := _area()
	if area.size.x <= 0.0 or rect.size.x <= 0.0:
		return
	zoom = clampf(minf(area.size.x / rect.size.x, area.size.y / rect.size.y), low, high)
	_world.scale = Vector2(zoom, zoom)
	_world.position = area.get_center() - rect.get_center() * zoom
	_clamp()
	_zoom_changed()


## When what a stone links to cannot all fit, the stone itself still must.
func _keep_in_view(id: String) -> void:
	var area := _area().grow(-(ORB_RADIUS + 40.0) * zoom)
	if not area.has_area():
		return
	var at := _world.position + node_center(network.nodes[id]) * zoom
	var inside := Vector2(clampf(at.x, area.position.x, area.end.x), clampf(at.y, area.position.y, area.end.y))
	_world.position += inside - at
	_clamp()


func focus_on(id: String) -> void:
	if not network.nodes.has(id):
		return
	_world.position = _area().get_center() - node_center(network.nodes[id]) * zoom
	_clamp()


func camera() -> Dictionary:
	return {"zoom": zoom, "position": _world.position}


func restore_camera(state: Dictionary) -> void:
	zoom = float(state.get("zoom", zoom))
	_world.scale = Vector2(zoom, zoom)
	_world.position = state.get("position", _world.position)
	_placed = true
	_clamp()
	_zoom_changed()


## Keeps part of the disc on screen.
func _clamp() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or network == null:
		return
	var reach := DISC_RADIUS * zoom
	var keep := minf(220.0, minf(size.x, size.y) * 0.4)
	_world.position.x = clampf(_world.position.x, keep - reach, size.x - keep + reach)
	_world.position.y = clampf(_world.position.y, keep - reach, size.y - keep + reach)


## Names fade out when zoomed far out, so the weave reads as a whole.
func _zoom_changed() -> void:
	var alpha := clampf((zoom / text_zoom() - 0.34) / 0.16, 0.0, 1.0)
	for button: NetworkNode in _buttons.values():
		button.label_alpha = alpha
		button.queue_redraw()
	queue_redraw()


func _on_resized() -> void:
	if network == null or size.x <= 0.0:
		return
	if not _placed:
		_placed = true
		# Next frame: the panel sets free_rect once its overlays are laid out.
		_place_first.call_deferred()
	else:
		_clamp()


func _place_first() -> void:
	if not is_inside_tree():
		return
	if not selected.is_empty():
		frame(selected)
	else:
		fit()


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
			queue_redraw()
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
		queue_redraw()
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
		button.view = self
		button.name = "Node_" + id.replace(":", "_")
		button.position = node_position(entry)
		button.size = NODE_SIZE
		button.custom_minimum_size = NODE_SIZE
		button.pressed.connect(_on_node_pressed.bind(id))
		_world.add_child(button)
		_buttons[id] = button
	_world.move_child(_labels, -1)
	_paths.clear()
	_dashes_cache.clear()
	for edge: Dictionary in network.edges:
		var path := _measure(_vein(edge))
		_paths.append(path)
		_dashes_cache.append(_dash_segments(path))
	_refresh_highlight()
	_zoom_changed()


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
		button.modulate.a = 1.0 if _related(id) else 0.5
		button.queue_redraw()
	_disc.queue_redraw()
	_flow.queue_redraw()
	_labels.queue_redraw()


## A vein flows outward: it leaves a stone along its ring's radius and
## arrives along the next one's, so the weave grows like roots.
func _vein(edge: Dictionary) -> PackedVector2Array:
	var from := node_center(network.nodes[edge["from"]])
	var to := node_center(network.nodes[edge["to"]])
	var reach := maxf(to.length() - from.length(), 60.0) * 0.5
	var curve := Curve2D.new()
	curve.add_point(from, Vector2.ZERO, from.normalized() * reach)
	curve.add_point(to, -to.normalized() * reach, Vector2.ZERO)
	var points := curve.tessellate(5, 2.0)
	# Trim to the sockets' edges.
	var trimmed := PackedVector2Array()
	var gap := ORB_RADIUS + 9.0
	for point in points:
		if point.distance_to(from) >= gap and point.distance_to(to) >= gap:
			trimmed.append(point)
	return trimmed if trimmed.size() >= 2 else PackedVector2Array([from, to])


static func _measure(points: PackedVector2Array) -> Dictionary:
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i].distance_to(points[i - 1]))
	return {"points": points, "lengths": lengths, "total": lengths[lengths.size() - 1]}


static func _point_at(path: Dictionary, distance: float) -> Vector2:
	var points: PackedVector2Array = path["points"]
	var lengths: PackedFloat32Array = path["lengths"]
	for i in range(1, points.size()):
		if lengths[i] >= distance:
			var span := maxf(lengths[i] - lengths[i - 1], 0.001)
			return points[i - 1].lerp(points[i], (distance - lengths[i - 1]) / span)
	return points[points.size() - 1]


# --- Drawing: screen ---------------------------------------------------------------

## Behind the weave: a deep glade at night, a soft glow where the disc sits
## and slow motes of Aether drifting up.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG.darkened(0.35))
	var center := _world.position if _world != null else size * 0.5
	var halo := DISC_RADIUS * zoom * 1.5
	draw_texture_rect(SkillOrb.glow_texture(), Rect2(center - Vector2(halo, halo), Vector2(halo, halo) * 2.0), false,
			Color(0.25, 0.45, 0.4, 0.22))
	if not _animate:
		return
	for i in MOTES:
		var seed_x := fmod(i * 0.6180339 + 0.13, 1.0)
		var speed := 8.0 + fmod(i * 7.31, 11.0)
		var y := size.y - fmod(_time * speed + i * 97.0, size.y + 40.0)
		var x := seed_x * size.x + sin(_time * 0.4 + i) * 14.0
		var fade := sin(fmod(_time * 0.3 + i * 0.37, 1.0) * PI)
		draw_circle(Vector2(x, y), 1.4 + fmod(i * 0.77, 1.6), Color(UiTheme.AETHER, 0.18 * fade))


# --- Drawing: the disc -------------------------------------------------------------

func _draw_disc() -> void:
	if network == null:
		return
	var canvas := _disc
	var font := get_theme_font("font", "Label")
	var bronze := UiTheme.BORDER
	canvas.draw_circle(Vector2.ZERO, DISC_RADIUS + 6.0, Color(0, 0, 0, 0.5))
	canvas.draw_circle(Vector2.ZERO, DISC_RADIUS, DISC)
	canvas.draw_texture_rect(SkillOrb.glow_texture(), Rect2(-Vector2.ONE * DISC_RADIUS, Vector2.ONE * DISC_RADIUS * 2.0),
			false, Color(UiTheme.ACCENT, 0.07))

	# Rim: a band between two bronze rings, ticked, with the sectors' names.
	var band_out := DISC_RADIUS - 6.0
	var band_in := DISC_RADIUS - 64.0
	canvas.draw_arc(Vector2.ZERO, band_out, 0.0, TAU, 256, bronze, 5.0, true)
	canvas.draw_arc(Vector2.ZERO, band_in, 0.0, TAU, 256, Color(bronze, 0.75), 2.5, true)
	for i in 144:
		var dir := Vector2.from_angle(i * TAU / 144.0)
		var long := i % 6 == 0
		canvas.draw_line(dir * band_in, dir * (band_in + (12.0 if long else 6.0)), Color(bronze, 0.55),
				1.5 if long else 1.0, true)
	for sector: Dictionary in network.sectors:
		var start: float = sector["start"]
		var dir := Vector2.from_angle(start)
		canvas.draw_line(dir * (HUB_RADIUS + 46.0), dir * band_in, Color(bronze, 0.16), 2.0, true)
		SkillOrb._diamond(canvas, dir * (band_in + band_out) * 0.5, 7.0, bronze)
		var middle := (start + float(sector["end"])) * 0.5
		_curved_text(canvas, font, str(sector["name"]).to_upper(), middle, (band_in + band_out) * 0.5 + 2.0, 34,
				Color(UiTheme.ACCENT, 0.85))

	# Carved channels for each ring that has stones on it.
	var rings := {}
	for id: String in network.order:
		rings[int(network.nodes[id]["ring"])] = true
	for ring: int in rings:
		var radius: float = RADII[ring]
		canvas.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 192, SkillOrb.GROOVE, 15.0, true)
		canvas.draw_arc(Vector2.ZERO, radius + 7.5, 0.0, TAU, 192, Color(bronze, 0.22), 1.5, true)
		canvas.draw_arc(Vector2.ZERO, radius - 7.5, 0.0, TAU, 192, Color(0, 0, 0, 0.4), 1.5, true)
	if network.has_hidden:
		# The rest of the weave waits, uncarved, out to the last ring.
		for ring in RADII.size():
			if rings.has(ring):
				continue
			for i in 72:
				var a := i * TAU / 72.0
				canvas.draw_arc(Vector2.ZERO, RADII[ring], a, a + TAU / 200.0, 3, Color(bronze, 0.25), 3.0, true)

	# Spokes from the hub to the foundation, lit where something is learned.
	for id: String in network.order:
		var entry: Dictionary = network.nodes[id]
		if int(entry["ring"]) != SkillNetwork.RING_FOUNDATION:
			continue
		var dir := Vector2.from_angle(float(entry["angle"]))
		var from := dir * (HUB_RADIUS + 14.0)
		var to := dir * (float(RADII[0]) - ORB_RADIUS - 9.0)
		canvas.draw_line(from, to, SkillOrb.GROOVE, 11.0, true)
		if SkillOrb.is_lit(entry["state"]):
			canvas.draw_line(from, to, Color(SkillOrb.color_of(entry), 0.75), 3.5, true)

	# Veins: grooves carved only where Aether runs or the selection points,
	# so the weave stays readable; the rest are faint scratches.
	var lit_any := not selected.is_empty()
	for i in network.edges.size():
		var edge: Dictionary = network.edges[i]
		if edge["met"] or edge["from"] == selected or edge["to"] == selected:
			canvas.draw_polyline(_paths[i]["points"], SkillOrb.GROOVE, 12.0, true)
	for i in network.edges.size():
		var edge: Dictionary = network.edges[i]
		var involved: bool = edge["from"] == selected or edge["to"] == selected
		var dim := lit_any and not involved
		var points: PackedVector2Array = _paths[i]["points"]
		var color := SkillOrb.color_of(network.nodes[edge["from"]])
		if edge["met"]:
			canvas.draw_polyline(points, Color(color, 0.22 if dim else 0.5), 9.0 if involved else 7.0, true)
			canvas.draw_polyline(points, Color(color.lightened(0.35), 0.35 if dim else 1.0), 3.0 if involved else 2.2, true)
		elif _dashes_cache[i].size() >= 2:
			canvas.draw_multiline(_dashes_cache[i], Color(UiTheme.TEXT_DIM, 0.12 if dim else (0.75 if involved else 0.32)),
					2.5 if involved else 1.6, true)

	_draw_hub(canvas)


## The moving layer: two motes of light along each lit vein toward what it
## opens, and the wreath turning slowly around the crest. Held still under
## Reduce motion.
func _draw_flowing() -> void:
	if network == null:
		return
	var glow := SkillOrb.glow_texture()
	for i in network.edges.size():
		var edge: Dictionary = network.edges[i]
		if not edge["met"] or (not selected.is_empty() and edge["from"] != selected and edge["to"] != selected):
			continue
		var path: Dictionary = _paths[i]
		var total: float = path["total"]
		if total <= 1.0:
			continue
		var color := SkillOrb.color_of(network.nodes[edge["from"]]).lightened(0.4)
		for k in 2:
			var distance := fmod(_time * 110.0 + i * 53.0 + k * total * 0.5, total) if _animate else total * (0.3 + 0.4 * k)
			var at := _point_at(path, distance)
			_flow.draw_texture_rect(glow, Rect2(at - Vector2(12, 12), Vector2(24, 24)), false, Color(color, 0.8))
			_flow.draw_circle(at, 2.6, Color(1, 1, 1, 0.9))
	var r := HUB_RADIUS
	for i in 28:
		var a := i * TAU / 28.0 + (_time * 0.05 if _animate else 0.0)
		var at := Vector2.from_angle(a) * (r + 30.0)
		var along := Vector2.from_angle(a + PI * 0.5)
		var out := Vector2.from_angle(a)
		_flow.draw_colored_polygon(PackedVector2Array([at - along * 9.0, at + out * 4.0, at + along * 9.0, at - out * 4.0]),
				Color(UiTheme.GOOD.darkened(0.35), 0.75))


## Dash segments along a vein, worked out once.
static func _dash_segments(path: Dictionary) -> PackedVector2Array:
	var segments := PackedVector2Array()
	var total: float = path["total"]
	var distance := 0.0
	while distance < total:
		segments.append(_point_at(path, distance))
		segments.append(_point_at(path, minf(distance + 10.0, total)))
		distance += 22.0
	return segments


## The champion's crest at the heart of the weave.
func _draw_hub(canvas: CanvasItem) -> void:
	var bronze := UiTheme.BORDER
	var r := HUB_RADIUS
	canvas.draw_texture_rect(SkillOrb.glow_texture(), Rect2(-Vector2.ONE * r * 2.4, Vector2.ONE * r * 4.8), false,
			Color(UiTheme.ACCENT, 0.28))
	canvas.draw_circle(Vector2.ZERO, r + 10.0, Color(0, 0, 0, 0.55))
	canvas.draw_circle(Vector2.ZERO, r, SkillOrb.SOCKET)
	canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, bronze, 5.0, true)
	canvas.draw_arc(Vector2.ZERO, r - 12.0, 0.0, TAU, 96, Color(bronze, 0.5), 1.5, true)
	for i in 24:
		var dir := Vector2.from_angle(i * TAU / 24.0)
		canvas.draw_line(dir * (r - 12.0), dir * (r - 4.0), Color(bronze, 0.6), 1.5, true)
	canvas.draw_circle(Vector2.ZERO, r - 18.0, UiTheme.ACCENT_DARK.darkened(0.45))
	SkillGlyphs.draw(canvas, "hub", Vector2(0, -4), r * 0.52, UiTheme.ACCENT)


## Text set along a circle, centred on `angle`; on the lower half it runs the
## other way so it always reads left to right.
static func _curved_text(canvas: CanvasItem, font: Font, text: String, angle: float, radius: float, font_size: int,
		color: Color) -> void:
	var spacing := 6.0
	var widths: Array[float] = []
	var total := 0.0
	for c in text:
		var w := font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
		widths.append(w)
		total += w
	var lower := sin(angle) > 0.15
	var direction := -1.0 if lower else 1.0
	var a := angle - direction * total * 0.5 / radius
	var ascent := font.get_ascent(font_size)
	for i in text.length():
		var mid := a + direction * widths[i] * 0.5 / radius
		var at := Vector2.from_angle(mid) * radius
		canvas.draw_set_transform(at, mid + (-PI * 0.5 if lower else PI * 0.5), Vector2.ONE)
		canvas.draw_char(font, Vector2(-(widths[i] - spacing) * 0.5, ascent * 0.35), text[i], font_size, color)
		a += direction * widths[i] / radius
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Drawing: labels above the stones ----------------------------------------------

func _draw_labels() -> void:
	if network == null:
		return
	var font := get_theme_font("font", "Label")
	# The champion's name on a ribbon under the crest.
	if not title.is_empty():
		var font_size := 24
		var text_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var w := text_size.x + 44.0
		var y := HUB_RADIUS + 4.0
		var ribbon := PackedVector2Array([Vector2(-w * 0.5 - 14, y), Vector2(w * 0.5 + 14, y), Vector2(w * 0.5, y + 18),
				Vector2(w * 0.5 + 14, y + 36), Vector2(-w * 0.5 - 14, y + 36), Vector2(-w * 0.5, y + 18)])
		_labels.draw_colored_polygon(ribbon, UiTheme.ACCENT_DARK)
		var outline := ribbon.duplicate()
		outline.append(ribbon[0])
		_labels.draw_polyline(outline, UiTheme.ACCENT, 1.5, true)
		_labels.draw_string(font, Vector2(-text_size.x * 0.5, y + 18 + font.get_ascent(font_size) * 0.38), title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("1d1609"))
	# The rank each lit vein asks for, next to the stone at its far end.
	for i in network.edges.size():
		var edge: Dictionary = network.edges[i]
		if selected.is_empty() or (edge["from"] != selected and edge["to"] != selected):
			continue
		var points: PackedVector2Array = _paths[i]["points"]
		var at: Vector2 = points[0] if edge["to"] == selected else points[points.size() - 1]
		var text := GameEnums.rank_name(int(edge["need"]))
		var font_size := 16
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box := Rect2(at - Vector2(text_size.x * 0.5 + 9, text_size.y * 0.5 + 3), text_size + Vector2(18, 6))
		var border: Color = UiTheme.ACCENT if edge["met"] else UiTheme.TEXT_DIM
		_labels.draw_style_box(UiTheme.box(Color(SkillOrb.SOCKET, 0.95), 9, border, 1, 0), box)
		_labels.draw_string(font, Vector2(box.position.x + 9, box.position.y + 3 + font.get_ascent(font_size)), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border)


## One stone in the weave, with its name underneath. The button keeps taps,
## hover tooltips and hit testing simple; SkillOrb does the drawing.
class NetworkNode extends Button:
	var entry: Dictionary
	var view: SkillNetworkView
	var selected := false
	var label_alpha := 1.0

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS
		flat = true

	func _ready() -> void:
		tooltip_text = "%s — %s" % [entry["name"], status_text(entry)]
		UiKit.add_press_feedback(self)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	static func status_text(node: Dictionary) -> String:
		var state: int = node["state"]
		if node["kind"] != "technique" and node["rank"] > 0:
			var text := GameEnums.rank_name(node["rank"])
			return text + " · highest" if state == SkillNetwork.State.MASTERED else text
		return ["Locked", "Needs a mentor", "Ready to learn", "Learned", "Learned"][state]

	func _draw() -> void:
		var t := view._time if view != null else 0.0
		SkillOrb.draw(self, SkillNetworkView.ORB_CENTER, SkillNetworkView.ORB_RADIUS, entry, t, selected)
		var alpha := 1.0 if selected else label_alpha
		if alpha <= 0.01:
			return
		var font := get_theme_font("font", "Label")
		var font_size := 19
		var text: String = entry["name"]
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at := Vector2((size.x - text_width) * 0.5, SkillNetworkView.ORB_CENTER.y + SkillNetworkView.ORB_RADIUS + 34.0)
		var locked: bool = entry["state"] == SkillNetwork.State.LOCKED
		var color := Color(UiTheme.TEXT_DIM if locked else UiTheme.TEXT, alpha * (0.7 if locked else 1.0))
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.75 * alpha))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
