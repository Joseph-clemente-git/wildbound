extends Node3D
## Story event scene (opening cinematic and chapter beats).
## Params: {"event": id, "next": route (default "lodge"), "next_params": {}}

const SHOTS := {
	"valley": [Vector3(18.0, 14.0, 34.0), Vector3(0.0, 2.0, -6.0)],
	"circle": [Vector3(11.5, 2.4, 6.0), Vector3(7.5, 0.8, 1.0)],
	"lodge": [Vector3(2.5, 2.4, 13.0), Vector3(0.0, 1.8, -8.0)],
	"porch": [Vector3(1.6, 2.0, -2.2), Vector3(-0.6, 1.7, -6.6)],
	"dog": [Vector3(1.2, 1.5, -1.6), Vector3(0.4, 1.1, -4.4)],
	"default": [Vector3(3.5, 2.6, 4.0), Vector3(0.0, 1.4, -5.0)],
}

var _camera: Camera3D
var _dialogue: DialogueBox
var _shot_tween: Tween


func _ready() -> void:
	var event: String = Router.params.get("event", "opening")
	WorldBuilder.home_valley(self, "dusk" if event == "opening" else "day")
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_set_shot("valley" if event == "opening" else "porch", 0.0)
	_spawn_cast()
	Sfx.play_ambient()
	var layer := CanvasLayer.new()
	add_child(layer)
	_dialogue = DialogueBox.new()
	layer.add_child(_dialogue)
	_dialogue.beat_started.connect(func(beat: Dictionary) -> void:
		_set_shot(beat.get("shot", "default"), 1.6))
	_dialogue.finished.connect(_on_finished)
	_dialogue.play(StoryEvents.get_event(event))


func _spawn_cast() -> void:
	var maren := ProceduralDogVisual.new(StoryEvents.MAREN_PALETTE)
	maren.position = Vector3(-0.6, 0.55, -6.9)
	maren.rotation.y = deg_to_rad(200.0)
	maren.scale = Vector3.ONE * 0.95
	maren.set_armor(GameEnums.ArmorWeight.LIGHT)
	add_child(maren)
	var champion := Game.champion()
	var dog: CharacterVisual = CharacterFactory.for_champion(champion) if champion != null else ProceduralDogVisual.new()
	dog.position = Vector3(0.4, 0.0, -4.4)
	dog.rotation.y = deg_to_rad(155.0)
	add_child(dog)


func _set_shot(shot: String, seconds: float) -> void:
	var data: Array = SHOTS.get(shot, SHOTS["default"])
	var target_position: Vector3 = data[0]
	var look: Vector3 = data[1]
	var target_basis := Transform3D(Basis(), target_position).looking_at(look).basis
	if seconds <= 0.0:
		_camera.global_transform = Transform3D(target_basis, target_position)
		return
	if _shot_tween != null:
		_shot_tween.kill()
	_shot_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shot_tween.tween_property(_camera, "global_transform", Transform3D(target_basis, target_position), seconds)


func _on_finished() -> void:
	Game.save()
	Router.go(Router.params.get("next", "lodge"), Router.params.get("next_params", {}))
