class_name AetherBolt
extends Node3D
## Glowing projectile body with a trail. BattleManager moves it; `burst()`
## plays the impact and frees it.

var color := Color.ORANGE
var school := "fire"
var size := 0.4


func _ready() -> void:
	var core := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.6
	mesh.height = size * 1.2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color.lightened(0.3)
	material.emission_enabled = true
	material.emission = color
	mesh.material = material
	core.mesh = mesh
	add_child(core)
	var trail := MagicVisuals.flame(Vector3.ZERO, size * 0.8)
	trail.local_coords = false
	trail.color_ramp.set_color(0, Color(color.lightened(0.3), 0.9))
	trail.color_ramp.set_color(1, Color(color.darkened(0.3), 0.0))
	add_child(trail)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 3.0
	add_child(light)


func burst() -> void:
	var parent := get_parent() as Node3D
	if parent != null:
		MagicVisuals.burst(parent, global_position, school, 30, 1.2, 0.5)
	Sfx.play("fire" if school == "fire" else "hit")
	queue_free()
