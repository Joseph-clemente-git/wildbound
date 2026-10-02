class_name UiKit
extends RefCounted
## Small factory helpers so screens can be composed in code consistently.
##
## Every interactive control created here respects the mobile minimum touch
## size and plays the shared UI audio hooks.


static func label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	if not variation.is_empty():
		node.theme_type_variation = variation
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func heading(text: String) -> Label:
	return label(text, "HeadingLabel")


static func rich(bbcode: String, fit: bool = true) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.bbcode_enabled = true
	node.text = bbcode
	node.fit_content = fit
	node.scroll_active = not fit
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	return node


static func button(text: String, on_pressed: Callable = Callable(), variation: String = "",
		min_width: float = 0.0) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(min_width, UiTheme.TOUCH_MIN)
	node.focus_mode = Control.FOCUS_NONE
	if not variation.is_empty():
		node.theme_type_variation = variation
	node.pressed.connect(func() -> void: Sfx.play("ui_click", 0.02))
	if on_pressed.is_valid():
		node.pressed.connect(on_pressed)
	return node


static func primary_button(text: String, on_pressed: Callable = Callable(), min_width: float = 0.0) -> Button:
	return button(text, on_pressed, "PrimaryButton", min_width)


static func vbox(separation: int = 12) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func hbox(separation: int = 12) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func grid(columns: int, separation: int = 12) -> GridContainer:
	var node := GridContainer.new()
	node.columns = columns
	node.add_theme_constant_override("h_separation", separation)
	node.add_theme_constant_override("v_separation", separation)
	return node


static func panel(variation: String = "") -> PanelContainer:
	var node := PanelContainer.new()
	if not variation.is_empty():
		node.theme_type_variation = variation
	return node


static func margin(all: int) -> MarginContainer:
	var node := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		node.add_theme_constant_override("margin_" + side, all)
	return node


static func spacer(vertical: bool = true) -> Control:
	var node := Control.new()
	if vertical:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func scroll(content: Control) -> ScrollContainer:
	var node := ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_child(content)
	return node


static func bar(value: float, max_value: float, color: Color, height: float = 14.0,
		show_text: bool = false) -> ProgressBar:
	var node := ProgressBar.new()
	node.max_value = maxf(max_value, 0.001)
	node.value = value
	node.show_percentage = show_text
	node.custom_minimum_size = Vector2(0, height)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_stylebox_override("fill", UiTheme.box(color, 8, Color.TRANSPARENT, 0, 0))
	return node


## A "Label: value" row with an optional progress bar.
static func stat_row(name: String, value_text: String, fill: float = -1.0,
		color: Color = UiTheme.ACCENT) -> Control:
	var row := vbox(4)
	var top := hbox(8)
	var name_label := label(name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var value_label := label(value_text)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(value_label)
	row.add_child(top)
	if fill >= 0.0:
		row.add_child(bar(fill, 1.0, color, 10.0))
	return row


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Full-screen dimmer + centered panel. Returns the content VBox.
static func modal(parent: Node, title: String, width: float = 640.0) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var box := panel()
	box.custom_minimum_size = Vector2(width, 0)
	center.add_child(box)
	var content := vbox(16)
	box.add_child(content)
	if not title.is_empty():
		content.add_child(heading(title))
	return content


## Removes the modal created by `modal()` given its content box.
static func close_modal(content: Control) -> void:
	var node: Node = content
	while node != null and not (node is ColorRect):
		node = node.get_parent()
	if node != null:
		node.queue_free()


## Simple yes/no confirmation dialog.
static func confirm(parent: Node, title: String, message: String, confirm_text: String,
		on_confirm: Callable, cancel_text: String = "Cancel") -> void:
	var content := modal(parent, title, 620.0)
	content.add_child(label(message, "", true))
	var row := hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(button(cancel_text, func() -> void: close_modal(content)))
	row.add_child(primary_button(confirm_text, func() -> void:
		close_modal(content)
		on_confirm.call()))
	content.add_child(row)


## Brief floating message near the top of the screen.
static func toast(parent: Node, text: String, color: Color = UiTheme.TEXT, seconds: float = 2.4) -> void:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.95), 14, UiTheme.BORDER, 2, 14))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label := label(text)
	text_label.add_theme_color_override("font_color", color)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(text_label)
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.position.y = 24
	parent.add_child(holder)
	holder.modulate.a = 0.0
	var tween := holder.create_tween()
	tween.tween_property(holder, "modulate:a", 1.0, 0.2)
	tween.tween_interval(seconds)
	tween.tween_property(holder, "modulate:a", 0.0, 0.35)
	tween.tween_callback(holder.queue_free)


## Full-rect margin container that respects device safe areas (notches, rounded
## corners) on top of a comfortable base margin.
static func safe_area(base_margin: int = 24) -> MarginContainer:
	var node := MarginContainer.new()
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var insets := safe_insets()
	node.add_theme_constant_override("margin_left", base_margin + int(insets.x))
	node.add_theme_constant_override("margin_top", base_margin + int(insets.y))
	node.add_theme_constant_override("margin_right", base_margin + int(insets.z))
	node.add_theme_constant_override("margin_bottom", base_margin + int(insets.w))
	return node


## Safe-area insets (left, top, right, bottom) in canvas units.
static func safe_insets() -> Vector4:
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0 or DisplayServer.get_name() == "headless":
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Rect2(Vector2.ZERO, window_size)
	if safe.size.x <= 0 or not screen.encloses(safe):
		return Vector4.ZERO
	# "expand" stretch: one canvas unit spans min(w / 1280, h / 720) pixels.
	var canvas_scale := maxf(1280.0 / window_size.x, 720.0 / window_size.y)
	return Vector4(safe.position.x, safe.position.y,
			window_size.x - safe.end.x, window_size.y - safe.end.y) * canvas_scale
