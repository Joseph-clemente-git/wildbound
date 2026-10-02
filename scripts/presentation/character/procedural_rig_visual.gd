class_name ProceduralRigVisual
extends CharacterVisual
## Shared construction for primitive-mesh bodies on the reusable humanoid rig
## (Root/Hips/Spine/Chest/Neck/Head, arms, legs, Tail). Species and people
## differ only in the meshes they hang on the same pivots, so every rig plays
## the shared CharacterAnimations clips.

var palette: Dictionary = {}
var right_hand: Node3D
var left_hand: Node3D
var aura_light: OmniLight3D

var _materials: Dictionary = {}  # palette key -> StandardMaterial3D
var _weapon_root: Node3D
var _offhand_root: Node3D
var _bones: Dictionary = {}


## Call at the end of a subclass _init once the rig is built.
func _finish_setup(hip_height: float) -> void:
	aura_light = OmniLight3D.new()
	aura_light.name = "Aura"
	aura_light.omni_range = 2.2
	aura_light.light_energy = 1.4
	aura_light.position = Vector3(0, 1.1, -0.2)
	aura_light.visible = false
	add_child(aura_light)
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	animation_player.add_animation_library("", CharacterAnimations.build_library(hip_height))
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("idle")
	_current_clip = "idle"


func bone(key: String) -> Node3D:
	return _bones.get(key)


func set_palette(new_palette: Dictionary) -> void:
	palette.merge(new_palette, true)
	for key: String in _materials:
		if palette.get(key) is Color:
			(_materials[key] as StandardMaterial3D).albedo_color = palette[key]


func set_weapon(new_weapon_type: String) -> void:
	weapon_type = new_weapon_type
	for child in _weapon_root.get_children():
		child.queue_free()
	for child in _offhand_root.get_children():
		child.queue_free()
	if new_weapon_type.is_empty():
		return
	var model := WeaponVisuals.build(new_weapon_type)
	if new_weapon_type == "shield" or new_weapon_type == "bow":
		_offhand_root.add_child(model)
	else:
		_weapon_root.add_child(model)


func set_aura(school: String) -> void:
	aura_school = school
	if school.is_empty():
		aura_light.visible = false
		return
	aura_light.visible = true
	aura_light.light_color = MagicVisuals.school_color(school)


# --- Construction helpers --------------------------------------------------------

## Materials for every Color entry of the palette, plus shared extras.
func _build_palette_materials(roughness: float = 0.92) -> void:
	for key: String in palette:
		if palette[key] is Color:
			_materials[key] = _make_material(palette[key], roughness)


func _make_material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _pivot(parent: Node3D, node_name: String, offset: Vector3, key: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = offset
	parent.add_child(node)
	_bones[key] = node
	return node


## Weapon / off-hand attachment point at the end of a forearm.
func _hand(fore: Node3D, prefix: String, side: float, offset: Vector3) -> Node3D:
	var hand := Node3D.new()
	hand.name = prefix + "Hand"
	hand.position = offset
	fore.add_child(hand)
	if side > 0:
		right_hand = hand
		_weapon_root = hand
	else:
		left_hand = hand
		_offhand_root = hand
	return hand


func _attach(parent: Node3D, mesh_instance: MeshInstance3D, offset: Vector3,
		rotation_euler: Vector3 = Vector3.ZERO, node_name: String = "",
		scale_factor: Vector3 = Vector3.ONE) -> MeshInstance3D:
	if not node_name.is_empty():
		mesh_instance.name = node_name
	mesh_instance.position = offset
	mesh_instance.rotation = rotation_euler
	mesh_instance.scale = scale_factor
	parent.add_child(mesh_instance)
	return mesh_instance


func _mesh(mesh: Mesh, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _materials[material_key]
	return instance


func _sphere(radius: float, material_key: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _mesh(mesh, material_key)


func _capsule(radius: float, height: float, material_key: String) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 14
	mesh.rings = 4
	return _mesh(mesh, material_key)


func _cylinder(top: float, bottom: float, height: float, material_key: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	return _mesh(mesh, material_key)


func _box(size: Vector3, material_key: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, material_key)


func _torus(inner: float, outer: float, material_key: String) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 8
	return _mesh(mesh, material_key)
