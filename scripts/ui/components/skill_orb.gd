class_name SkillOrb
extends RefCounted
## Draws one node of the Aether Weave: an Aether stone set in a bronze
## socket, tinted by its family (fundamentals amber, discipline copper,
## weapons steel, each Aether school its own colour, techniques Aether
## blue), with a glyph for what it is. Its state reads without colour too:
##
## - Locked        unlit stone, dim glyph
## - Needs mentor  half-lit stone, broken ring
## - Ready         half-lit stone, pulsing Aether halo
## - Learned       lit stone and glow; rank pips and progress on the socket
## - Mastered      lit stone, golden double ring and a star
##
## Shading comes from small textures generated once, so no image assets.

const S := SkillNetwork.State
const SOCKET := Color("0e1311")
const GROOVE := Color("090c0b")
const GOLD := Color("f2cf6b")

const GROUP_COLORS := {
	SkillNetwork.GROUP_FUNDAMENTALS: Color("e3a857"),
	SkillNetwork.GROUP_NATURAL: Color("5fc0a2"),
	SkillNetwork.GROUP_ATTRIBUTES: Color("e07a5f"),
	SkillNetwork.GROUP_DISCIPLINE: Color("d4876a"),
	SkillNetwork.GROUP_WEAPONS: Color("a9bccf"),
	SkillNetwork.GROUP_TECHNIQUES: Color("7fd3d8"),
}

static var _body: Texture2D
static var _shine: Texture2D
static var _glow: Texture2D


static func color_of(entry: Dictionary) -> Color:
	if entry.get("group", "") == SkillNetwork.GROUP_MAGIC:
		return MagicVisuals.school_color(GameEnums.target_id(entry["id"]))
	return GROUP_COLORS.get(entry.get("group", ""), UiTheme.ACCENT)


static func is_lit(state: int) -> bool:
	return state == S.LEARNED or state == S.MASTERED


## Soft round glow, white; tint with `modulate`.
static func glow_texture() -> Texture2D:
	if _glow == null:
		_glow = _make(64, func(d: float, _x: float, _y: float) -> Color:
			var a := clampf(1.0 - d, 0.0, 1.0)
			return Color(1, 1, 1, a * a))
	return _glow


static func _body_texture() -> Texture2D:
	if _body == null:
		var light := Vector3(-0.45, -0.55, 0.7).normalized()
		_body = _make(96, func(d: float, x: float, y: float) -> Color:
			if d > 1.0:
				return Color(1, 1, 1, 0)
			var z := sqrt(maxf(1.0 - d * d, 0.0))
			var lit := maxf(Vector3(x, y, z).dot(light), 0.0)
			var value := (0.32 + 0.78 * lit) * (0.55 + 0.45 * z)
			# A thin bright band just inside the rim: light caught by the glass.
			value += smoothstep(0.82, 0.97, d) * 0.22 * (1.0 - smoothstep(0.97, 1.0, d))
			return Color(value, value, value, clampf((1.0 - d) * 48.0, 0.0, 1.0)))
	return _body


static func _shine_texture() -> Texture2D:
	if _shine == null:
		_shine = _make(64, func(_d: float, x: float, y: float) -> Color:
			var spot := Vector2(x + 0.36, y + 0.42).length() / 0.36
			return Color(1, 1, 1, clampf(1.0 - spot, 0.0, 1.0) * 0.9))
	return _shine


## Builds a square texture from fn(distance from centre 0-1, x, y) -> Color.
static func _make(size: int, fn: Callable) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for py in size:
		for px in size:
			var x := (px + 0.5) / size * 2.0 - 1.0
			var y := (py + 0.5) / size * 2.0 - 1.0
			image.set_pixel(px, py, fn.call(Vector2(x, y).length(), x, y))
	return ImageTexture.create_from_image(image)


## Draws a node on `canvas`. `t` is time for the pulses (0 to hold still).
static func draw(canvas: CanvasItem, center: Vector2, radius: float, entry: Dictionary, t: float = 0.0,
		selected: bool = false) -> void:
	var state: int = entry.get("state", S.LOCKED)
	var color := color_of(entry)
	var lit := is_lit(state)
	var socket_r := radius + 7.0

	if lit or selected:
		var glow_r := radius * (2.7 if selected else 2.2)
		canvas.draw_texture_rect(glow_texture(), Rect2(center - Vector2(glow_r, glow_r), Vector2(glow_r, glow_r) * 2.0),
				false, Color(color, 0.5 if selected else 0.32))
	# Bronze socket with a bevel.
	canvas.draw_circle(center, socket_r + 2.0, Color(0, 0, 0, 0.45))
	canvas.draw_circle(center, socket_r, SOCKET)
	canvas.draw_arc(center, socket_r, 0.0, TAU, 48, UiTheme.BORDER, 2.5, true)
	canvas.draw_arc(center, socket_r - 3.5, PI * 0.9, PI * 1.9, 24, Color(0, 0, 0, 0.6), 2.0, true)

	var body := color
	match state:
		S.LOCKED:
			body = color.lerp(Color(0.42, 0.44, 0.42), 0.75).darkened(0.55)
		S.OPEN:
			body = color.lerp(Color(0.5, 0.5, 0.5), 0.35).darkened(0.42)
		S.READY:
			body = color.darkened(0.22)
	var rect := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	canvas.draw_texture_rect(_body_texture(), rect, false, body)
	canvas.draw_texture_rect(_shine_texture(), rect, false, Color(1, 1, 1, 0.85 if lit else 0.3))

	var glyph := Color(1, 1, 1, 0.95) if lit else (Color(0.85, 0.85, 0.8, 0.75) if state != S.LOCKED else Color(0.6, 0.62, 0.6, 0.45))
	SkillGlyphs.draw(canvas, str(entry.get("id", "")), center, radius * 0.62, glyph)

	match state:
		S.OPEN:
			for i in 8:
				var a := i * TAU / 8.0
				canvas.draw_arc(center, socket_r + 4.0, a, a + TAU / 16.0, 6, Color(UiTheme.ACCENT_DARK, 0.9), 2.0, true)
		S.READY:
			var pulse := 0.5 + 0.5 * sin(t * 3.2)
			canvas.draw_arc(center, socket_r + 4.0 + pulse * 4.0, 0.0, TAU, 48,
					Color(UiTheme.AETHER, 0.95 - pulse * 0.55), 2.5, true)
		S.MASTERED:
			canvas.draw_arc(center, socket_r + 3.5, 0.0, TAU, 48, GOLD, 2.0, true)
			canvas.draw_arc(center, socket_r + 7.0, 0.0, TAU, 48, Color(GOLD, 0.6), 1.2, true)
			_star(canvas, center + Vector2(0, -socket_r - 12.0), 6.0, GOLD)

	if entry.get("kind", "") != "technique":
		_pips(canvas, center, socket_r, entry)
		if state == S.LEARNED and float(entry.get("progress", 0.0)) > 0.0:
			canvas.draw_arc(center, socket_r, -PI * 0.5, -PI * 0.5 + TAU * float(entry["progress"]), 48,
					UiTheme.ACCENT, 3.0, true)

	if selected:
		var spin := t * 0.9
		for i in 4:
			var a := spin + i * TAU / 4.0
			canvas.draw_arc(center, socket_r + 13.0, a - 0.45, a + 0.45, 12, UiTheme.TEXT, 2.5, true)
			var tip := center + Vector2.from_angle(a + 0.78) * (socket_r + 20.0)
			var inward := Vector2.from_angle(a + 0.78)
			canvas.draw_colored_polygon(PackedVector2Array([tip - inward * 7.0, tip + inward.orthogonal() * 4.0,
					tip - inward.orthogonal() * 4.0]), UiTheme.ACCENT)


## One pip per rank in an arc under the stone; ranks past the animal's
## potential are only faint dots.
static func _pips(canvas: CanvasItem, center: Vector2, socket_r: float, entry: Dictionary) -> void:
	var rank: int = entry.get("rank", 0)
	var cap: int = entry.get("cap", GameEnums.Rank.MASTER)
	var count := GameEnums.Rank.MASTER
	for i in count:
		var a := PI * 0.5 + (i - (count - 1) * 0.5) * 0.24
		var at := center + Vector2.from_angle(a) * (socket_r + 7.5)
		var level := count - i
		if level <= rank:
			_diamond(canvas, at, 3.6, GOLD if entry.get("state", 0) == S.MASTERED else UiTheme.ACCENT)
		elif level <= cap:
			_diamond(canvas, at, 3.2, Color(0, 0, 0, 0.7))
			canvas.draw_polyline(_diamond_points(at, 3.2, true), Color(UiTheme.TEXT_DIM, 0.7), 1.0, true)
		else:
			canvas.draw_circle(at, 1.3, Color(UiTheme.TEXT_DIM, 0.35))


static func _diamond_points(at: Vector2, r: float, closed: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	if closed:
		points.append(points[0])
	return points


static func _diamond(canvas: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	canvas.draw_colored_polygon(_diamond_points(at, r), color)


static func _star(canvas: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		points.append(at + Vector2.from_angle(-PI * 0.5 + i * TAU / 8.0) * (r if i % 2 == 0 else r * 0.38))
	canvas.draw_colored_polygon(points, color)
