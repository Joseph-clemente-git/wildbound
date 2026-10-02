class_name ActionPad
extends Control
## Right-hand combat buttons (mechanics §68): Attack, Heavy, Dodge, Block
## (hold) and Magic. Built from TouchScreenButtons mapped to input actions so
## every finger is tracked independently. Mirrors for left-handed players.

const BUTTONS := [
	# action, label, offset from the anchor corner, radius, colour
	["attack", "Attack", Vector2(-120, -120), 74.0, Color("e3a857")],
	["heavy", "Heavy", Vector2(-280, -86), 54.0, Color("d9674e")],
	["dodge", "Dodge", Vector2(-108, -290), 54.0, Color("8cc46f")],
	["block", "Block", Vector2(-262, -236), 50.0, Color("7fa8d8")],
	["magic", "Aether", Vector2(-410, -70), 48.0, Color("7fd3d8")],
]

var magic_label := ""
var magic_color := UiTheme.AETHER
var _buttons: Dictionary = {}  # action -> TouchScreenButton
var _cooldown_ratio := 0.0
var _magic_enabled := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry: Array in BUTTONS:
		var button := TouchScreenButton.new()
		button.action = entry[0]
		var radius: float = entry[3]
		button.texture_normal = _disc(radius, Color(entry[4], 0.42))
		button.texture_pressed = _disc(radius, Color(entry[4], 0.85))
		var shape := CircleShape2D.new()
		shape.radius = radius
		button.shape = shape
		button.shape_centered = true
		button.passby_press = true
		add_child(button)
		var label := Label.new()
		label.text = entry[1]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(radius * 2.0, radius * 2.0)
		label.add_theme_font_size_override("font_size", UiTheme.fs(22 if radius > 60 else 18))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.name = "Label"
		button.add_child(label)
		_buttons[entry[0]] = button
	resized.connect(_layout)
	Settings.changed.connect(func(_k: String, _v: Variant) -> void: _layout())
	_layout()


func _layout() -> void:
	var scale_factor: float = Settings.get_value("controls_scale")
	var mirror: bool = Settings.get_value("left_handed")
	var insets := UiKit.safe_insets()
	for entry: Array in BUTTONS:
		var button: TouchScreenButton = _buttons[entry[0]]
		var radius: float = entry[3] * scale_factor
		var offset: Vector2 = entry[2] * scale_factor
		var corner := Vector2(size.x - insets.z - 20.0, size.y - insets.w - 10.0)
		if mirror:
			offset.x = -offset.x
			corner.x = insets.x + 20.0
		button.scale = Vector2.ONE * scale_factor
		button.position = corner + offset - Vector2(radius, radius)


## Teach by doing: briefly pulse the button that fits the moment.
func pulse(action: String) -> void:
	var button: TouchScreenButton = _buttons.get(action)
	if button == null or button.has_meta("pulsing") or Settings.get_value("reduce_motion"):
		return
	button.set_meta("pulsing", true)
	var base := button.scale
	var tween := create_tween()
	tween.tween_property(button, "scale", base * 1.18, 0.16)
	tween.tween_property(button, "scale", base, 0.2)
	tween.tween_property(button, "scale", base * 1.12, 0.14)
	tween.tween_property(button, "scale", base, 0.18)
	tween.tween_callback(func() -> void: button.remove_meta("pulsing"))


func set_magic(label: String, color: Color, enabled: bool) -> void:
	magic_label = label
	magic_color = color
	_magic_enabled = enabled
	var button: TouchScreenButton = _buttons["magic"]
	button.visible = enabled
	(button.get_node("Label") as Label).text = label


## 0 = ready, 1 = just used.
func set_cooldown(ratio: float) -> void:
	if absf(ratio - _cooldown_ratio) > 0.01:
		_cooldown_ratio = ratio
		var button: TouchScreenButton = _buttons["magic"]
		button.modulate = Color(1, 1, 1, 0.45 if ratio > 0.0 else 1.0)
		queue_redraw()


func _draw() -> void:
	if not _magic_enabled or _cooldown_ratio <= 0.0:
		return
	var button: TouchScreenButton = _buttons["magic"]
	var radius := 48.0 * button.scale.x
	var center := button.position + Vector2(radius, radius)
	draw_arc(center, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - _cooldown_ratio), 40, magic_color, 5.0, true)


static func _disc(radius: float, color: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.86, 0.9, 0.97, 1.0])
	gradient.colors = PackedColorArray([color, color.darkened(0.15), Color(1, 1, 1, color.a + 0.1),
			Color(1, 1, 1, color.a * 0.6), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = int(radius * 2.0)
	texture.height = int(radius * 2.0)
	return texture
