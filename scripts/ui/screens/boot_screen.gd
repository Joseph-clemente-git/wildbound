extends Control
## Boot: (engine splash) → studio card → title with the atmospheric world shot.
## Tapping skips the studio card.

const STUDIO_SECONDS := 2.2

var _done := false


func _ready() -> void:
	theme = UiTheme.get_theme()
	var background := ColorRect.new()
	background.color = UiTheme.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := UiKit.vbox(10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	var paw := UiKit.label("✦", "TitleLabel")
	paw.add_theme_color_override("font_color", UiTheme.ACCENT)
	paw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(paw)
	var studio := UiKit.label("LANTERN & PAW", "HeadingLabel")
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(studio)
	var presents := UiKit.label("presents", "DimLabel")
	presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(presents)
	column.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(column, "modulate:a", 1.0, 0.6)
	tween.tween_interval(STUDIO_SECONDS - 1.2)
	tween.tween_property(column, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_continue)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_continue()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_continue()


func _continue() -> void:
	if _done:
		return
	_done = true
	Router.go("title", {"intro": true})
