class_name ProceduralDogVisual
extends ProceduralRigVisual
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

var _armor_pieces: Array[Node] = []


func _init(initial_palette: Dictionary = {}) -> void:
	palette = DEFAULT_PALETTE.duplicate()
	palette.merge(initial_palette, true)
	_build_materials()
	_build_rig()
	_finish_setup(HIP_HEIGHT)
	set_armor(GameEnums.ArmorWeight.LIGHT)


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


# --- Construction --------------------------------------------------------------

func _build_materials() -> void:
	_build_palette_materials()
	_materials["leather"] = _make_material(Color("6b4a2b"), 0.8)
	_materials["metal"] = _make_material(Color("9aa3a8"), 0.35, 0.75)
	_materials["metal_dark"] = _make_material(Color("4d5257"), 0.4, 0.7)
	_materials["nose"] = _make_material(Color("1c1412"), 0.3)
	_materials["eye_shine"] = _make_material(Color.WHITE, 0.2)
	_materials["inner_ear"] = _make_material(Color("d9a08a"), 0.9)
	_materials["claw"] = _make_material(Color("e8e0d0"), 0.5)
	for key: String in ["fur", "fur_light", "fur_dark", "cloth", "leather", "metal", "metal_dark"]:
		_flash_materials.append(_materials[key])


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

	_build_tail(_pivot(hips, "Tail", Vector3(0, 0.03, 0.15), "tail"))

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
		_hand(fore, prefix, side, Vector3(0, -FOREARM - 0.04, 0))

	# Neck and head
	var neck := _pivot(chest, "Neck", Vector3(0, 0.2, -0.02), "neck")
	_attach(neck, _capsule(0.085, 0.2, "fur"), Vector3(0, 0.05, 0))
	var head := _pivot(neck, "Head", Vector3(0, 0.15, -0.02), "head")
	_build_head(head)
	_build_extras(chest, hips)


## Tail: three segments curling up and back. Other animals override.
func _build_tail(tail: Node3D) -> void:
	_attach(tail, _capsule(0.05, 0.22, "fur"), Vector3(0, 0, 0.1), Vector3(PI * 0.5, 0, 0))
	_attach(tail, _capsule(0.045, 0.2, "fur"), Vector3(0, 0.0, 0.26), Vector3(PI * 0.5, 0, 0))
	_attach(tail, _sphere(0.055, "fur_light"), Vector3(0, 0.0, 0.38), Vector3.ZERO, "TailTip", Vector3(0.9, 0.9, 1.4))


## Dog head: skull, snout, nose, eyes and pointed ears. Other animals override.
func _build_head(head: Node3D) -> void:
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




## Fins, wings and the like on other animals.
func _build_extras(_chest: Node3D, _hips: Node3D) -> void:
	pass


## Armor pieces live under their bone but are tracked so they can be swapped.
func _armor_part(parent: Node3D, mesh_instance: MeshInstance3D, offset: Vector3,
		rotation_euler: Vector3 = Vector3.ZERO, scale_factor: Vector3 = Vector3.ONE) -> void:
	_attach(parent, mesh_instance, offset, rotation_euler, "", scale_factor)
	_armor_pieces.append(mesh_instance)
