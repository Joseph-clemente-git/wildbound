class_name SkillGlyphs
extends RefCounted
## Line glyphs for the Aether Weave, drawn in code so they scale cleanly and
## need no assets. Each is described in a unit box (-1..1, y down) and drawn
## with a dark outline under a light stroke so it reads on any stone.
## Discipline skills reuse their fundamental's glyph inside a small ring.

const REFINES := {
	"skill:attack_control": "skill:attack", "skill:timing": "skill:timing",
	"skill:defense_control": "skill:defense", "skill:dodge_control": "skill:dodge",
	"skill:block_control": "skill:block", "skill:stamina_discipline": "skill:stamina",
	"skill:recovery_control": "skill:recovery",
}


static func draw(canvas: CanvasItem, id: String, center: Vector2, size: float, color: Color) -> void:
	var refined: bool = REFINES.has(id) and REFINES[id] != id
	var key: String = REFINES.get(id, id) if refined else id
	var scale := size * (0.78 if refined else 1.0)
	var strokes := shapes(key)
	var width := maxf(size * 0.16, 1.5)
	for pass_index in 2:
		var stroke_color := Color(0, 0, 0, 0.55 * color.a) if pass_index == 0 else color
		var stroke_width := width + 2.2 if pass_index == 0 else width
		for shape: Array in strokes:
			var points := PackedVector2Array()
			for p: Vector2 in shape[1]:
				points.append(center + p * scale)
			if shape[0] == "fill":
				if pass_index == 1:
					canvas.draw_colored_polygon(points, color)
				else:
					var closed := points.duplicate()
					closed.append(points[0])
					canvas.draw_polyline(closed, stroke_color, 2.2, true)
			else:
				canvas.draw_polyline(points, stroke_color, stroke_width, true)
	if refined:
		canvas.draw_arc(center, size * 1.02, 0.0, TAU, 32, Color(color, 0.8), maxf(size * 0.08, 1.0), true)


## [["line" | "fill", [Vector2, ...]], ...] in unit space.
static func shapes(id: String) -> Array:
	match id:
		"skill:attack":
			return [_l([-0.7, 0.7, 0.7, -0.7]), _l([-0.75, 0.15, -0.15, -0.75]), _l([0.15, 0.75, 0.75, 0.15])]
		"skill:movement":
			return [_l([-0.75, -0.6, -0.15, 0, -0.75, 0.6]), _l([0.05, -0.6, 0.65, 0, 0.05, 0.6])]
		"skill:dodge":
			return [_line(_arc(Vector2(0.1, 0.1), 0.65, PI * 0.95, PI * 2.2, 10)), _l([0.45, -0.75, 0.75, -0.42, 0.35, -0.3])]
		"skill:defense", "weapon:shield":
			return [_line(_shield(1.0), true)]
		"skill:block":
			return [_line(_shield(1.0), true), _l([-0.55, -0.1, 0.55, -0.1])]
		"skill:stamina":
			return [_line(_drop(), true)]
		"skill:recovery":
			return [_l([0, -0.7, 0, 0.7]), _l([-0.7, 0, 0.7, 0])]
		"skill:timing":
			return [_line([Vector2(-0.55, -0.75), Vector2(0.55, -0.75), Vector2(-0.55, 0.75), Vector2(0.55, 0.75), Vector2(-0.55, -0.75)])]
		"skill:positioning":
			return [_line([Vector2(0, -0.85), Vector2(0.32, 0), Vector2(0, 0.85), Vector2(-0.32, 0), Vector2(0, -0.85)]),
					_l([-0.8, 0, 0.8, 0])]
		"skill:swimming":
			return [_line(_wave(-0.3)), _line(_wave(0.3))]
		"skill:flight":
			return [_line(_arc(Vector2(-0.35, 0.45), 0.6, -PI * 0.95, -PI * 0.25, 8)),
					_line(_arc(Vector2(0.35, 0.45), 0.6, -PI * 0.75, -PI * 0.05, 8))]
		"weapon:sword":
			return [_l([0, -0.85, 0, 0.45]), _l([-0.4, 0.45, 0.4, 0.45]), _l([0, 0.45, 0, 0.85])]
		"weapon:hammer":
			return [_l([0, -0.3, 0, 0.85]), ["fill", _rect(-0.55, -0.8, 0.55, -0.3)]]
		"weapon:dagger":
			return [_l([0, -0.55, 0, 0.3]), _l([-0.32, 0.3, 0.32, 0.3]), _l([0, 0.3, 0, 0.7])]
		"weapon:spear":
			return [_l([0, -0.3, 0, 0.9]), ["fill", [Vector2(0, -0.9), Vector2(0.22, -0.3), Vector2(-0.22, -0.3)]]]
		"weapon:axe":
			return [_l([-0.15, -0.8, -0.15, 0.85]), ["fill", [Vector2(-0.15, -0.75)] + _arc(Vector2(-0.15, -0.25), 0.65, -PI * 0.42, PI * 0.42, 8) + [Vector2(-0.15, 0.25)]]]
		"weapon:bow":
			return [_line(_arc(Vector2(-0.55, 0), 0.95, -PI * 0.36, PI * 0.36, 10)), _l([0.21, -0.85, 0.21, 0.85]),
					_l([-0.75, 0, 0.6, 0])]
		"magic:fire":
			return [["fill", _flame()]]
		"magic:frost":
			return [_l([0, -0.85, 0, 0.85]), _l([-0.74, -0.42, 0.74, 0.42]), _l([-0.74, 0.42, 0.74, -0.42])]
		"magic:wind":
			return [_line(_arc(Vector2(-0.1, -0.35), 0.35, PI, PI * 2.3, 8) + [Vector2(-0.8, -0.0)]),
					_line(_arc(Vector2(0.2, 0.25), 0.3, -PI * 0.5, PI * 0.6, 8) + [Vector2(-0.8, 0.0)])]
		"magic:earth":
			return [["fill", [Vector2(-0.85, 0.6), Vector2(-0.25, -0.55), Vector2(0.1, 0.05), Vector2(0.35, -0.25), Vector2(0.85, 0.6)]]]
		"magic:lightning":
			return [["fill", [Vector2(0.15, -0.9), Vector2(-0.45, 0.1), Vector2(-0.02, 0.1), Vector2(-0.2, 0.9),
					Vector2(0.45, -0.15), Vector2(0.02, -0.15)]]]
		"magic:nature":
			return [_line(_arc(Vector2(-0.45, -0.1), 0.85, -PI * 0.33, PI * 0.42, 10) + _arc(Vector2(0.45, 0.1), 0.85, PI * 0.67, PI * 1.42, 10)),
					_l([-0.55, 0.6, 0.45, -0.5])]
		"stat:strength":
			return [["fill", [Vector2(0, -0.85), Vector2(0.6, -0.15), Vector2(0.22, -0.15), Vector2(0.22, 0.75),
					Vector2(-0.22, 0.75), Vector2(-0.22, -0.15), Vector2(-0.6, -0.15)]]]
		"stat:agility":
			return [_l([-0.6, 0.8, 0.55, -0.75]), _l([-0.2, 0.25, -0.55, 0.05]), _l([0.05, -0.08, -0.25, -0.35]),
					_l([0.28, -0.4, 0.05, -0.68]), _l([-0.2, 0.25, 0.15, 0.35]), _l([0.05, -0.08, 0.4, 0.0])]
		"hub":
			return [["fill", _oval(Vector2(0, 0.32), 0.48, 0.38)], ["fill", _oval(Vector2(-0.62, -0.18), 0.16, 0.22)],
					["fill", _oval(Vector2(-0.24, -0.52), 0.16, 0.22)], ["fill", _oval(Vector2(0.24, -0.52), 0.16, 0.22)],
					["fill", _oval(Vector2(0.62, -0.18), 0.16, 0.22)]]
	if id.begins_with("technique:"):
		var star := PackedVector2Array()
		for i in 8:
			star.append(Vector2.from_angle(-PI * 0.5 + i * TAU / 8.0) * (0.9 if i % 2 == 0 else 0.28))
		return [["fill", Array(star)]]
	return [["fill", _oval(Vector2.ZERO, 0.35, 0.35)]]


static func _l(values: Array) -> Array:
	var points: Array = []
	for i in range(0, values.size(), 2):
		points.append(Vector2(values[i], values[i + 1]))
	return ["line", points]


static func _line(points: Array, closed: bool = false) -> Array:
	var copy := points.duplicate()
	if closed:
		copy.append(points[0])
	return ["line", copy]


static func _arc(center: Vector2, radius: float, from: float, to: float, steps: int) -> Array:
	var points: Array = []
	for i in steps + 1:
		points.append(center + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * radius)
	return points


static func _oval(center: Vector2, rx: float, ry: float) -> Array:
	var points: Array = []
	for i in 14:
		var a := i * TAU / 14.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points


static func _rect(x0: float, y0: float, x1: float, y1: float) -> Array:
	return [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]


static func _shield(s: float) -> Array:
	return [Vector2(-0.65, -0.75) * s, Vector2(0.65, -0.75) * s, Vector2(0.62, 0.0) * s, Vector2(0, 0.85) * s,
			Vector2(-0.62, 0.0) * s]


static func _drop() -> Array:
	return [Vector2(0, -0.85)] + _arc(Vector2(0, 0.25), 0.55, -PI * 0.15, PI * 1.15, 12)


static func _wave(y: float) -> Array:
	var points: Array = []
	for i in 9:
		var x := lerpf(-0.8, 0.8, i / 8.0)
		points.append(Vector2(x, y + sin(x * PI * 1.6) * 0.18))
	return points


static func _flame() -> Array:
	return [Vector2(0, -0.9), Vector2(0.3, -0.35), Vector2(0.55, 0.15), Vector2(0.45, 0.6), Vector2(0, 0.85),
			Vector2(-0.45, 0.6), Vector2(-0.55, 0.15), Vector2(-0.25, -0.15), Vector2(-0.1, 0.2), Vector2(0.05, -0.3)]
