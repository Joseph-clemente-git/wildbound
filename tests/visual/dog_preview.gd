extends Node3D
## Visual check for the procedural champion rig: cycles every animation clip
## with each armor weight and weapon. Render with Movie Maker, e.g.:
##   godot --path . --write-movie out.png --fixed-fps 10 res://tests/visual/dog_preview.tscn

const CLIP_SECONDS := 1.2

var _dog: ProceduralDogVisual
var _label: Label3D
var _clips: Array[String] = []
var _index := -1
var _timer := 0.0


func _ready() -> void:
	WorldBuilder.environment(self, "day")
	WorldBuilder.ground(self, 30.0)
	var camera := Camera3D.new()
	camera.position = Vector3(1.9, 1.4, 2.6)
	add_child(camera)
	camera.look_at(Vector3(0, 0.95, 0))
	_dog = ProceduralDogVisual.new()
	_dog.rotation.y = deg_to_rad(-25)
	add_child(_dog)
	_label = Label3D.new()
	_label.position = Vector3(-0.9, 2.1, 0)
	_label.font_size = 48
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	_clips.assign(_dog.animation_player.get_animation_list())
	_next()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= CLIP_SECONDS:
		_timer = 0.0
		_next()


func _next() -> void:
	_index += 1
	if _index >= _clips.size():
		get_tree().quit()
		return
	var clip := _clips[_index]
	_dog.set_armor(_index % 3)
	_dog.set_weapon(["sword", "hammer", "sword"][_index % 3])
	_dog.play(clip, CLIP_SECONDS)
	_label.text = clip
