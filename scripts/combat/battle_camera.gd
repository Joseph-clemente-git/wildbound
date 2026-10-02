class_name BattleCamera
extends Camera3D
## Mobile battle camera (mechanics §69): stays behind the player, keeps both
## combatants in view, pulls back as they separate, never leaves the arena's
## camera limit and shakes lightly on heavy impacts (if enabled).

var player: Node3D
var opponent: Node3D
var limit := 16.0
var _shake := 0.0
var _look := Vector3.ZERO


func _ready() -> void:
	fov = 58.0
	if player != null:
		snap()


func snap() -> void:
	var goal := _goal()
	position = goal[0]
	_look = goal[1]
	look_at(_look)


func shake(strength: float) -> void:
	var amount: float = Settings.get_value("shake_strength")
	if amount > 0.0:
		_shake = maxf(_shake, strength * amount)


func _process(delta: float) -> void:
	if player == null or opponent == null:
		return
	var goal := _goal()
	position = position.lerp(goal[0], clampf(delta * 4.0, 0.0, 1.0))
	_look = _look.lerp(goal[1], clampf(delta * 6.0, 0.0, 1.0))
	look_at(_look)
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		h_offset = randf_range(-1.0, 1.0) * _shake * 0.15
		v_offset = randf_range(-1.0, 1.0) * _shake * 0.15
	else:
		h_offset = 0.0
		v_offset = 0.0


## [camera position, look target]
func _goal() -> Array:
	var a := Vector3(player.position.x, 0, player.position.z)
	var b := Vector3(opponent.position.x, 0, opponent.position.z)
	var separation := a.distance_to(b)
	var away := (a - b).normalized() if separation > 0.05 else Vector3.BACK
	# Offset slightly to the side so the player never hides the opponent.
	var side := away.cross(Vector3.UP) * 1.2
	var distance := clampf(3.4 + separation * 0.55, 3.9, 8.5)
	var height := clampf(2.2 + separation * 0.3, 2.6, 5.0)
	var target_position := a + away * distance + side + Vector3(0, height, 0)
	var flat := Vector3(target_position.x, 0, target_position.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		target_position = Vector3(flat.x, target_position.y, flat.z)
	var look := a.lerp(b, 0.4) + Vector3(0, 1.0, 0)
	return [target_position, look]
