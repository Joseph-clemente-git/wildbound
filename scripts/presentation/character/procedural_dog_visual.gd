class_name ProceduralDogVisual
extends CharacterVisual
## Humanoid dog built from primitive meshes on the reusable humanoid rig.
##
## This is the placeholder for the Blender master character: upright, two arms,
## two hands, two legs, dog head with ears and snout, tail, and fur colouring.
## Bone pivots use the shared names so CharacterAnimations drive it directly.

const HIP_HEIGHT := 0.9
const THIGH := 0.42
const SHIN := 0.4
const UPPER_ARM := 0.3
const FOREARM := 0.28

const DEFAULT_PALETTE := {
	"fur": Color("a8703c"),
	"fur_light": Color("f0dcb8"),
	"fur_dark": Color("4a3020"),
	"eye": Color("2b1a0e"),
	"scarf": Color("b8433a"),
	"cloth": Color("5d4a35"),
}

var palette: Dictionary = DEFAULT_PALETTE.duplicate()
var right_hand: Node3D
var left_hand: Node3D
var aura_light: OmniLight3D

var _materials: Dictionary = {}  # palette key -> StandardMaterial3D
var _armor_pieces: Array[Node] = []
var _weapon_root: Node3D
var _offhand_root: Node3D
var _bones: Dictionary = {}


func _init(initial_palette: Dictionary = {}) -> void:
	palette.merge(initial_palette, true)
	_build_materials()
	_build_rig()
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	animation_player.add_animation_library("", CharacterAnimations.build_library(HIP_HEIGHT))
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("idle")
	_current_clip = "idle"
	set_armor(GameEnums.ArmorWeight.LIGHT)


func bone(key: String) -> Node3D:
	return _bones.get(key)


func set_palette(new_palette: Dictionary) -> void:
	palette.merge(new_palette, true)
	for key: String in _materials:
		if palette.has(key):
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


func set_armor(weight: int) -> void:
	armor_weight = weight
	for piece in _armor_pieces:
		if is_instance_valid(piece):
			piece.free()
	_armor_pieces.clear()
	var chest: Node3D = _bones["chest"]
	var hips: Node3D = _bones["hips"]
	# Every champion of the lodge wears its scarf.
	_armor_part(_bones["neck"], _torus(0.11, 0.17, "scarf"), Vector3(0, -0.02, 0), Vector3(0.2, 0, 0))
	match weight:
		GameEnums.ArmorWeight.LIGHT:
			_armor_part(chest, _capsule(0.215, 0.36, "cloth"), Vector3(0, -0.02, 0.01), Vector3.ZERO, Vector3(1.0, 1.0, 0.82))
		GameEnums.ArmorWeight.MEDIUM:
			_armor_part(chest, _capsule(0.225, 0.4, "leather"), Vector3(0, -0.02, 0.01), Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
			for side: float in [-1.0, 1.0]:
				_armor_part(chest, _sphere(0.11, "leather"), Vector3(0.24 * side, 0.1, 0), Vector3.ZERO, Vector3(1.1, 0.7, 1.0))
			_armor_part(hips, _torus(0.17, 0.21, "metal_dark"), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 1.6, 0.85))
		GameEnums.ArmorWeight.HEAVY:
			_armor_part(chest, _capsule(0.235, 0.42, "metal"), Vector3(0, -0.02, 0.0), Vector3.ZERO, Vector3(1.05, 1.0, 0.9))
			_armor_part(hips, _cylinder(0.2, 0.24, 0.18, "metal_dark"), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
			for side: float in [-1.0, 1.0]:
				var key := "l_" if side < 0 else "r_"
				_armor_part(chest, _sphere(0.14, "metal"), Vector3(0.26 * side, 0.11, 0), Vector3.ZERO, Vector3(1.15, 0.75, 1.1))
				_armor_part(_bones[key + "shin"], _capsule(0.075, 0.26, "metal"), Vector3(0, -0.2, -0.01))
				_armor_part(_bones[key + "fore"], _capsule(0.07, 0.2, "metal"), Vector3(0, -0.13, 0))


func set_aura(school: String) -> void:
	aura_school = school
	if school.is_empty():
		aura_light.visible = false
		return
	aura_light.visible = true
	aura_light.light_color = MagicVisuals.school_color(school)


# --- Construction --------------------------------------------------------------

func _build_materials() -> void:
	for key: String in palette:
		_materials[key] = _make_material(palette[key], 0.92)
	_materials["leather"] = _make_material(Color("6b4a2b"), 0.8)
	_materials["metal"] = _make_material(Color("9aa3a8"), 0.35, 0.75)
	_materials["metal_dark"] = _make_material(Color("4d5257"), 0.4, 0.7)
	_materials["nose"] = _make_material(Color("1c1412"), 0.3)
	_materials["eye_shine"] = _make_material(Color.WHITE, 0.2)
	_materials["inner_ear"] = _make_material(Color("d9a08a"), 0.9)
	_materials["claw"] = _make_material(Color("e8e0d0"), 0.5)
	for key: String in ["fur", "fur_light", "fur_dark", "cloth", "leather", "metal", "metal_dark"]:
		_flash_materials.append(_materials[key])


func _make_material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _build_rig() -> void:
	var rig := Node3D.new()
	rig.name = "Rig"
	add_child(rig)

	var hips := _pivot(rig, "Hips", Vector3(0, HIP_HEIGHT, 0), "hips")
	_attach(hips, _sphere(0.19, "fur"), Vector3(0, 0, 0), Vector3.ZERO, "Pelvis", Vector3(1.05, 0.75, 0.85))

	# Legs: digitigrade-looking shins and long paws.
	for side: float in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		var key := "l_" if side < 0 else "r_"
		var leg := _pivot(hips, prefix + "Leg", Vector3(0.11 * side, -0.03, 0), key + "leg")
		_attach(leg, _capsule(0.085, THIGH + 0.08, "fur"), Vector3(0, -THIGH * 0.5, 0))
		var shin := _pivot(leg, prefix + "Shin", Vector3(0, -THIGH, 0), key + "shin")
		_attach(shin, _capsule(0.065, SHIN + 0.06, "fur"), Vector3(0, -SHIN * 0.5, 0))
		var foot := _capsule(0.06, 0.24, "fur_dark")
		_attach(shin, foot, Vector3(0, -SHIN - 0.03, -0.06), Vector3(PI * 0.5, 0, 0))
		for toe: float in [-0.03, 0.0, 0.03]:
			_attach(shin, _sphere(0.012, "claw"), Vector3(toe, -SHIN - 0.05, -0.18))

	# Tail: three segments curling up and back.
	var tail := _pivot(hips, "Tail", Vector3(0, 0.03, 0.15), "tail")
	_attach(tail, _capsule(0.05, 0.22, "fur"), Vector3(0, 0, 0.1), Vector3(PI * 0.5, 0, 0))
	_attach(tail, _capsule(0.045, 0.2, "fur"), Vector3(0, 0.0, 0.26), Vector3(PI * 0.5, 0, 0))
	_attach(tail, _sphere(0.055, "fur_light"), Vector3(0, 0.0, 0.38), Vector3.ZERO, "TailTip", Vector3(0.9, 0.9, 1.4))

	var spine := _pivot(hips, "Spine", Vector3(0, 0.1, 0), "spine")
	_attach(spine, _capsule(0.165, 0.42, "fur"), Vector3(0, 0.12, 0), Vector3.ZERO, "Belly", Vector3(1.0, 1.0, 0.8))
	_attach(spine, _sphere(0.12, "fur_light"), Vector3(0, 0.1, -0.08), Vector3.ZERO, "BellyFur", Vector3(1.0, 1.5, 0.6))

	var chest := _pivot(spine, "Chest", Vector3(0, 0.3, 0), "chest")
	_attach(chest, _sphere(0.2, "fur"), Vector3(0, 0.02, 0), Vector3.ZERO, "Ribcage", Vector3(1.25, 1.0, 0.9))
	_attach(chest, _sphere(0.13, "fur_light"), Vector3(0, 0.02, -0.12), Vector3.ZERO, "ChestFur", Vector3(1.0, 1.2, 0.55))

	# Arms
	for side: float in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		var key := "l_" if side < 0 else "r_"
		var arm := _pivot(chest, prefix + "Arm", Vector3(0.235 * side, 0.1, 0), key + "arm")
		_attach(arm, _sphere(0.085, "fur"), Vector3.ZERO)
		_attach(arm, _capsule(0.07, UPPER_ARM + 0.06, "fur"), Vector3(0, -UPPER_ARM * 0.5, 0))
		var fore := _pivot(arm, prefix + "Forearm", Vector3(0, -UPPER_ARM, 0), key + "fore")
		_attach(fore, _capsule(0.06, FOREARM + 0.05, "fur"), Vector3(0, -FOREARM * 0.5, 0))
		_attach(fore, _sphere(0.068, "fur_dark"), Vector3(0, -FOREARM - 0.03, 0), Vector3.ZERO, "Paw", Vector3(1.0, 1.1, 0.9))
		var hand := Node3D.new()
		hand.name = prefix + "Hand"
		hand.position = Vector3(0, -FOREARM - 0.04, 0)
		fore.add_child(hand)
		if side > 0:
			right_hand = hand
			_weapon_root = hand
		else:
			left_hand = hand
			_offhand_root = hand

	# Neck and head
	var neck := _pivot(chest, "Neck", Vector3(0, 0.2, -0.02), "neck")
	_attach(neck, _capsule(0.085, 0.2, "fur"), Vector3(0, 0.05, 0))
	var head := _pivot(neck, "Head", Vector3(0, 0.15, -0.02), "head")
	_attach(head, _sphere(0.165, "fur"), Vector3(0, 0.06, 0), Vector3.ZERO, "Skull", Vector3(1.0, 0.95, 1.05))
	_attach(head, _sphere(0.1, "fur_light"), Vector3(0, -0.01, -0.12), Vector3.ZERO, "Cheeks", Vector3(1.3, 0.8, 0.8))
	_attach(head, _capsule(0.075, 0.22, "fur_light"), Vector3(0, 0.0, -0.2), Vector3(PI * 0.5, 0, 0), "Snout", Vector3(1.0, 1.0, 0.85))
	_attach(head, _sphere(0.04, "nose"), Vector3(0, 0.02, -0.31), Vector3.ZERO, "Nose", Vector3(1.2, 0.9, 1.0))
	_attach(head, _sphere(0.08, "fur"), Vector3(0, 0.08, -0.12), Vector3.ZERO, "Brow", Vector3(1.3, 0.55, 0.9))
	for side: float in [-1.0, 1.0]:
		_attach(head, _sphere(0.028, "eye"), Vector3(0.07 * side, 0.07, -0.15))
		_attach(head, _sphere(0.009, "eye_shine"), Vector3(0.075 * side, 0.08, -0.175))
		var ear := _pivot(head, "LeftEar" if side < 0 else "RightEar",
				Vector3(0.1 * side, 0.17, 0.02), "l_ear" if side < 0 else "r_ear")
		var ear_mesh := PrismMesh.new()
		ear_mesh.size = Vector3(0.13, 0.2, 0.04)
		_attach(ear, _mesh(ear_mesh, "fur_dark"), Vector3(0, 0.08, 0), Vector3(0, 0, -0.22 * side))
		var inner := PrismMesh.new()
		inner.size = Vector3(0.08, 0.13, 0.02)
		_attach(ear, _mesh(inner, "inner_ear"), Vector3(0, 0.065, -0.018), Vector3(0, 0, -0.22 * side))

	aura_light = OmniLight3D.new()
	aura_light.name = "Aura"
	aura_light.omni_range = 2.2
	aura_light.light_energy = 1.4
	aura_light.position = Vector3(0, 1.1, -0.2)
	aura_light.visible = false
	add_child(aura_light)


func _pivot(parent: Node3D, node_name: String, offset: Vector3, key: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = offset
	parent.add_child(node)
	_bones[key] = node
	return node


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


## Armor pieces live under their bone but are tracked so they can be swapped.
func _armor_part(parent: Node3D, mesh_instance: MeshInstance3D, offset: Vector3,
		rotation_euler: Vector3 = Vector3.ZERO, scale_factor: Vector3 = Vector3.ONE) -> void:
	_attach(parent, mesh_instance, offset, rotation_euler, "", scale_factor)
	_armor_pieces.append(mesh_instance)


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


func _torus(inner: float, outer: float, material_key: String) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 8
	return _mesh(mesh, material_key)
