class_name CharacterVisual
extends Node3D
## Presentation-only interface for any champion body.
##
## Gameplay never touches meshes or bones: it calls `play()`, `set_locomotion()`
## and the equipment setters. A procedural rig (ProceduralDogVisual) implements
## it today; a Blender-imported rig with the same bone names and clip names can
## implement it later without touching combat code (see docs/ASSET_PIPELINE.md).

signal clip_finished(clip: String)

const BLEND_TIME := 0.12

var animation_player: AnimationPlayer
var weapon_type: String = ""
var armor_weight: int = -1
var aura_school: String = ""
var _current_clip := ""
var _locomotion_clip := "idle"
var _locked := false
var _flash_materials: Array[StandardMaterial3D] = []
var _flash_tween: Tween


## Plays a clip. `duration > 0` time-scales the clip to last exactly that long.
## Locked clips (attacks, hits...) are not interrupted by locomotion updates.
func play(clip: String, duration: float = -1.0, lock: bool = true, blend: float = BLEND_TIME) -> void:
	if animation_player == null or not animation_player.has_animation(clip):
		return
	var speed := 1.0
	if duration > 0.0:
		speed = animation_player.get_animation(clip).length / duration
	_locked = lock
	_current_clip = clip
	animation_player.speed_scale = 1.0
	if animation_player.current_animation == clip:
		# Restart a clip that is already playing (e.g. consecutive attacks).
		animation_player.seek(0.0, true)
	animation_player.play(clip, blend, speed)


## Called every frame with the movement speed ratio (0 idle, ~0.5 walk, 1 run).
func set_locomotion(speed_ratio: float, combat: bool = false) -> void:
	var clip := ("combat_idle" if combat else "idle")
	if speed_ratio > 0.65:
		clip = "run"
	elif speed_ratio > 0.08:
		clip = "walk"
	_locomotion_clip = clip
	if _locked:
		return
	if _current_clip != clip:
		_current_clip = clip
		animation_player.play(clip, 0.18)
	if clip == "walk" or clip == "run":
		animation_player.speed_scale = clampf(speed_ratio * (1.6 if clip == "walk" else 1.0), 0.6, 1.5)
	else:
		animation_player.speed_scale = 1.0


## Returns to locomotion after a locked clip.
func release() -> void:
	_locked = false
	_current_clip = ""
	animation_player.speed_scale = 1.0
	set_locomotion(0.0 if _locomotion_clip.ends_with("idle") else 0.5, _locomotion_clip == "combat_idle")


func is_locked() -> bool:
	return _locked


func current_clip() -> String:
	return _current_clip


func has_clip(clip: String) -> bool:
	return animation_player != null and animation_player.has_animation(clip)


## Brief emissive flash used for hit feedback.
func flash(color: Color, seconds: float = 0.16) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	for material in _flash_materials:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
	_flash_tween = create_tween()
	_flash_tween.tween_interval(seconds)
	_flash_tween.tween_callback(func() -> void:
		for material in _flash_materials:
			material.emission_enabled = false)


# --- Overridden by concrete rigs ---------------------------------------------

func set_weapon(_weapon_type: String) -> void:
	pass


func set_armor(_weight: int) -> void:
	pass


func set_aura(_school: String) -> void:
	pass


func set_palette(_palette: Dictionary) -> void:
	pass


func _on_animation_finished(clip: StringName) -> void:
	clip_finished.emit(String(clip))
