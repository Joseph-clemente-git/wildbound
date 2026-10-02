class_name TouchJoystick
extends Control
## Floating joystick for the left side of the screen (mechanics §68).
## Touch anywhere in its area to place it; drag to move. Pushing to the rim
## counts as sprint. Supports multi-touch (tracks its own finger).

const RADIUS := 90.0
const DEADZONE := 0.12

var output := Vector2.ZERO
var sprinting := false

var _finger := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _rest_center := Vector2.ZERO


func _ready() -> void:
	# Raw _input (not _gui_input) so the joystick finger and button fingers
	# are tracked independently on multi-touch screens.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_place_rest)
	_place_rest()


func _place_rest() -> void:
	_rest_center = Vector2(size.x * 0.32, size.y - RADIUS * 1.4)
	if _finger == -1:
		_center = _rest_center
		_knob = _center
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and _finger == -1 and Rect2(Vector2.ZERO, size).has_point(local):
			_finger = event.index
			_center = local
			_knob = _center
			queue_redraw()
		elif not event.pressed and event.index == _finger:
			_release()
	elif event is InputEventScreenDrag and event.index == _finger:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var offset: Vector2 = local - _center
		_knob = _center + offset.limit_length(RADIUS)
		var value := offset / RADIUS
		output = value.limit_length(1.0) if value.length() > DEADZONE else Vector2.ZERO
		sprinting = value.length() > 1.15
		queue_redraw()


func _release() -> void:
	_finger = -1
	output = Vector2.ZERO
	sprinting = false
	_center = _rest_center
	_knob = _center
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release()


func _draw() -> void:
	var active := _finger != -1
	draw_circle(_center, RADIUS, Color(0, 0, 0, 0.28 if active else 0.18))
	draw_arc(_center, RADIUS, 0, TAU, 48, Color(UiTheme.TEXT, 0.35 if active else 0.2), 3.0, true)
	draw_circle(_knob, RADIUS * 0.42, Color(UiTheme.ACCENT if sprinting else UiTheme.TEXT, 0.55 if active else 0.3))
