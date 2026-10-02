class_name PlayerController
extends RefCounted
## Turns touch controls / keyboard / gamepad into combatant intents.
## Movement is camera-relative so "up" on the joystick moves away from the
## camera, toward the opponent.

var fighter: Combatant
var camera: Camera3D
var joystick: TouchJoystick
var enabled := true
var _block_toggled := false


func _init(player_fighter: Combatant, battle_camera: Camera3D, stick: TouchJoystick) -> void:
	fighter = player_fighter
	camera = battle_camera
	joystick = stick


func update(_delta: float) -> void:
	if not enabled:
		fighter.move_input = Vector2.ZERO
		fighter.block_held = false
		fighter.sprint = false
		return
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint")
	if joystick != null and joystick.output.length() > stick.length():
		stick = joystick.output
		sprinting = sprinting or joystick.sprinting
	var forward := Vector3.FORWARD
	if camera != null:
		forward = -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	var world := right * stick.x + forward * -stick.y
	fighter.move_input = Vector2(world.x, world.z).limit_length(1.0)
	fighter.sprint = sprinting
	if Settings.get_value("toggle_block"):
		if Input.is_action_just_pressed("block"):
			_block_toggled = not _block_toggled
		fighter.block_held = _block_toggled and not fighter.is_exhausted()
		if fighter.is_exhausted():
			_block_toggled = false
	else:
		fighter.block_held = Input.is_action_pressed("block")
	for action: String in ["attack", "heavy", "dodge", "magic"]:
		if Input.is_action_just_pressed(action):
			fighter.request(action)
