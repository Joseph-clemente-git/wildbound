class_name StatBar
extends Control
## Stat bar that shows where a value comes from: natural attribute, natural
## growth from battle experience, trainer development, and the potential cap.

const BASE_COLOR := Color("b9a27a")
const GROWTH_COLOR := Color("8cc46f")
const TRAINED_COLOR := Color("e3a857")
const MODIFIER_COLOR := Color("7fd3d8")

var base := 0.0
var growth := 0.0
var trained := 0.0
var modifier := 0.0
var potential := 100.0
var max_value := 100.0


func _init() -> void:
	custom_minimum_size = Vector2(120, 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(champion: Champion, stat: String) -> StatBar:
	base = champion.base_stat(stat)
	growth = float(champion.natural_growth.get(stat, 0.0))
	trained = float(champion.trained.get(stat, 0.0))
	var developed := champion.developed_stat(stat)
	# Clamp the parts to what actually counts after the potential limit.
	var over := base + growth + trained - developed
	trained = maxf(trained - over, 0.0)
	modifier = champion.equipment_modifier(stat)
	potential = champion.potential(stat)
	queue_redraw()
	return self


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0, 0, 0, 0.45))
	var x := 0.0
	for part: Array in [[base, BASE_COLOR], [growth, GROWTH_COLOR], [trained, TRAINED_COLOR]]:
		var width := size.x * float(part[0]) / max_value
		if width > 0.0:
			draw_rect(Rect2(x, 0, width, size.y), part[1])
			x += width
	if modifier != 0.0:
		var width := size.x * absf(modifier) / max_value
		var start := x if modifier > 0.0 else x - width
		draw_rect(Rect2(start, size.y * 0.6, width, size.y * 0.4), MODIFIER_COLOR if modifier > 0 else UiTheme.BAD)
	var cap_x := size.x * potential / max_value
	draw_line(Vector2(cap_x, -2), Vector2(cap_x, size.y + 2), UiTheme.TEXT, 2.0)


static func legend() -> Control:
	var row := UiKit.hbox(14)
	for entry: Array in [["Natural", BASE_COLOR], ["Battle growth", GROWTH_COLOR],
			["Trainer development", TRAINED_COLOR], ["Equipment", MODIFIER_COLOR]]:
		var swatch := ColorRect.new()
		swatch.color = entry[1]
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(UiKit.label(entry[0], "DimLabel"))
	var cap := UiKit.label("│ potential", "DimLabel")
	row.add_child(cap)
	return row
