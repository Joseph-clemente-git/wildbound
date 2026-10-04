class_name ProceduralHumanVisual
extends ProceduralRigVisual
## A person built from primitives on the same humanoid rig as the champions:
## mentors, the lodge's old owner and other Keepers. Because the pivots are
## shared, people play every CharacterAnimations clip.
##
## Appearance keys (all optional):
##   Colors: skin, hair, beard, tunic, trousers, boots, accent, eye
##   hair_style: "short" | "long" | "bun" | "twin_buns" | "bald" | "hood"
##   beard: bool   robe: bool   height: float (scale)   build: float (width)
##   head_size: float (head scale; a little larger reads younger)
##   dress: bool — a fitted, knee-length high-collared dress (qipao) in the
##     tunic color, trimmed and buttoned in the accent color, over bare legs
##     and slippers

const HIP_HEIGHT := 0.95
const THIGH := 0.45
const SHIN := 0.44
const UPPER_ARM := 0.3
const FOREARM := 0.27

const DEFAULT_APPEARANCE := {
	"skin": Color("dcb08a"),
	"hair": Color("4a3222"),
	"beard": false,
	"tunic": Color("4f6b8a"),
	"trousers": Color("4a3f33"),
	"boots": Color("3a2a1e"),
	"accent": Color("c9a24a"),
	"eye": Color("2a2018"),
	"hair_style": "short",
	"robe": false,
	"dress": false,
	"head_size": 1.0,
	"height": 1.0,
	"build": 1.0,
}

## The lodge's old owner: white hair and beard, a long robe, a walking stick.
const ELDER := {
	"skin": Color("d8b291"), "hair": Color("e6e2da"), "beard_color": Color("ecebe6"), "beard": true,
	"tunic": Color("6b4f3a"), "trousers": Color("4a3a2e"), "boots": Color("2e231a"),
	"accent": Color("b8433a"), "hair_style": "bald", "robe": true, "height": 0.95, "build": 1.05,
}

var appearance: Dictionary = {}


func _init(initial_appearance: Dictionary = {}) -> void:
	appearance = DEFAULT_APPEARANCE.duplicate()
	appearance.merge(initial_appearance, true)
	palette = {}
	for key: String in appearance:
		if appearance[key] is Color:
			palette[key] = appearance[key]
	if not palette.has("beard_color"):
		palette["beard_color"] = palette["hair"]
	_build_palette_materials(0.85)
	_materials["skin"].roughness = 0.7
	_materials["mouth"] = _make_material(Color("8a4a3e"), 0.6)
	_materials["eye_white"] = _make_material(Color("f2eee6"), 0.4)
	for key: String in ["skin", "tunic", "trousers", "hair", "beard_color", "boots"]:
		_flash_materials.append(_materials[key])
	_build_rig()
	_finish_setup(HIP_HEIGHT)
	scale = Vector3.ONE * float(appearance["height"])


## People in the lodge do not wear champion armor; clothing is fixed.
func set_armor(weight: int) -> void:
	armor_weight = weight


func _build_rig() -> void:
	var width: float = appearance["build"]
	var robe: bool = appearance["robe"]
	var dress: bool = appearance["dress"]
	var rig := Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	var hips := _pivot(rig, "Hips", Vector3(0, HIP_HEIGHT, 0), "hips")
	_attach(hips, _sphere(0.165, "tunic" if dress else "trousers"), Vector3.ZERO, Vector3.ZERO, "Pelvis",
			Vector3(1.1 * width, 0.7, 0.8))
	if dress:
		# A slim skirt to the knee, with a trimmed hem.
		_attach(hips, _cylinder(0.175 * width, 0.165 * width, 0.5, "tunic"), Vector3(0, -0.23, 0), Vector3.ZERO,
				"Dress", Vector3(1.0, 1.0, 0.78))
		_attach(hips, _torus(0.155, 0.175, "accent"), Vector3(0, -0.47, 0), Vector3.ZERO, "DressHem",
				Vector3(width, 0.6, 0.78))
	else:
		_attach(hips, _torus(0.14, 0.18, "accent"), Vector3(0, 0.08, 0), Vector3.ZERO, "Belt", Vector3(width, 1.4, 0.82))
	if robe:
		_attach(hips, _cylinder(0.19 * width, 0.33 * width, 0.86, "tunic"), Vector3(0, -0.4, 0), Vector3.ZERO, "Robe",
				Vector3(1.0, 1.0, 0.85))

	for side: float in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		var key := "l_" if side < 0 else "r_"
		var leg := _pivot(hips, prefix + "Leg", Vector3(0.095 * side * width, -0.03, 0), key + "leg")
		if dress:
			# Thighs stay dress-colored and end under the hem, so a stride never
			# shows through; bare shins and slim slippers below.
			_attach(leg, _capsule(0.07, THIGH - 0.02, "tunic"), Vector3(0, -THIGH * 0.45, 0))
		else:
			_attach(leg, _capsule(0.075, THIGH + 0.08, "trousers"), Vector3(0, -THIGH * 0.5, 0))
		var shin := _pivot(leg, prefix + "Shin", Vector3(0, -THIGH, 0), key + "shin")
		if dress:
			_attach(shin, _capsule(0.05, SHIN + 0.04, "skin"), Vector3(0, -SHIN * 0.45, 0))
			_attach(shin, _cylinder(0.05, 0.052, 0.07, "boots"), Vector3(0, -SHIN + 0.01, 0))
			_attach(shin, _capsule(0.046, 0.22, "boots"), Vector3(0, -SHIN - 0.025, -0.05), Vector3(PI * 0.5, 0, 0),
					"", Vector3(1.0, 1.0, 0.75))
		else:
			_attach(shin, _capsule(0.06, SHIN + 0.04, "trousers"), Vector3(0, -SHIN * 0.45, 0))
			_attach(shin, _cylinder(0.062, 0.058, 0.2, "boots"), Vector3(0, -SHIN + 0.07, 0))
			_attach(shin, _capsule(0.058, 0.25, "boots"), Vector3(0, -SHIN - 0.02, -0.05), Vector3(PI * 0.5, 0, 0))

	# People have no tail, but the pivot keeps the shared clips valid.
	_pivot(hips, "Tail", Vector3(0, 0.03, 0.12), "tail")

	var spine := _pivot(hips, "Spine", Vector3(0, 0.1, 0), "spine")
	_attach(spine, _capsule(0.15, 0.42, "tunic"), Vector3(0, 0.12, 0), Vector3.ZERO, "Torso",
			Vector3(1.05 * width, 1.0, 0.72))
	var chest := _pivot(spine, "Chest", Vector3(0, 0.3, 0), "chest")
	_attach(chest, _sphere(0.18, "tunic"), Vector3(0, 0.02, 0), Vector3.ZERO, "Ribcage",
			Vector3(1.25 * width, 1.0, 0.72))
	if dress:
		_build_dress_bodice(chest, width)
	else:
		_attach(chest, _torus(0.06, 0.09, "accent"), Vector3(0, 0.15, -0.01), Vector3(0.2, 0, 0), "Collar",
				Vector3(1.1, 1.0, 0.9))

	for side: float in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		var key := "l_" if side < 0 else "r_"
		var arm := _pivot(chest, prefix + "Arm", Vector3(0.22 * side * width, 0.1, 0), key + "arm")
		_attach(arm, _sphere(0.075, "tunic"), Vector3.ZERO)
		if dress:
			# Short cap sleeves edged in the accent color; bare arms below.
			_attach(arm, _capsule(0.062, 0.16, "tunic"), Vector3(0, -0.04, 0), Vector3.ZERO, prefix + "Sleeve")
			_attach(arm, _torus(0.05, 0.066, "accent"), Vector3(0, -0.11, 0))
			_attach(arm, _capsule(0.048, UPPER_ARM + 0.04, "skin"), Vector3(0, -UPPER_ARM * 0.5, 0))
		else:
			_attach(arm, _capsule(0.058, UPPER_ARM + 0.05, "tunic"), Vector3(0, -UPPER_ARM * 0.5, 0))
		var fore := _pivot(arm, prefix + "Forearm", Vector3(0, -UPPER_ARM, 0), key + "fore")
		_attach(fore, _capsule(0.044 if dress else 0.05, FOREARM + 0.04, "tunic" if robe else "skin"),
				Vector3(0, -FOREARM * 0.5, 0))
		_attach(fore, _sphere(0.05, "skin"), Vector3(0, -FOREARM - 0.03, 0), Vector3.ZERO, "HandMesh", Vector3(0.9, 1.15, 0.7))
		_hand(fore, prefix, side, Vector3(0, -FOREARM - 0.04, 0))

	var neck := _pivot(chest, "Neck", Vector3(0, 0.17, 0), "neck")
	_attach(neck, _capsule(0.052, 0.14, "skin"), Vector3(0, 0.04, 0))
	var head := _pivot(neck, "Head", Vector3(0, 0.12, 0), "head")
	head.scale = Vector3.ONE * float(appearance["head_size"])
	_build_face(head)
	_build_hair(head)


## The qipao's upper half: a standing mandarin collar and the curved opening
## across the chest, fastened with knotted buttons.
func _build_dress_bodice(chest: Node3D, width: float) -> void:
	_attach(chest, _cylinder(0.058, 0.066, 0.075, "tunic"), Vector3(0, 0.19, -0.005), Vector3.ZERO, "Collar")
	_attach(chest, _torus(0.054, 0.064, "accent"), Vector3(0, 0.228, -0.005), Vector3.ZERO, "CollarTrim",
			Vector3(1.0, 0.5, 1.0))
	# The opening sweeps from the collar down toward the wearer's right underarm,
	# laid on the ribcage surface in short segments, with knotted buttons.
	var points: Array[Vector3] = []
	for i in 5:
		var t := float(i) / 4.0
		points.append(_on_ribcage(lerpf(0.012, 0.13, t) * width, lerpf(0.16, 0.04, t), width))
	for i in 4:
		var from := points[i]
		var to := points[i + 1]
		_attach(chest, _box(Vector3(from.distance_to(to) + 0.01, 0.012, 0.012), "accent"), (from + to) * 0.5,
				Vector3(0, 0, atan2(to.y - from.y, to.x - from.x)), "Placket%d" % i)
	for i in [0, 2, 4]:
		_attach(chest, _sphere(0.012, "accent"), points[i] + Vector3(0, 0, -0.006), Vector3.ZERO, "FrogButton%d" % i)


## A point on the front of the ribcage ellipsoid (chest space), just proud of the cloth.
func _on_ribcage(x: float, y: float, width: float) -> Vector3:
	var radii := Vector3(0.225 * width, 0.18, 0.13)
	var dy := y - 0.02
	var depth := sqrt(maxf(0.0, 1.0 - pow(x / radii.x, 2.0) - pow(dy / radii.y, 2.0)))
	return Vector3(x, y, -radii.z * depth - 0.006)


func _build_face(head: Node3D) -> void:
	_attach(head, _sphere(0.112, "skin"), Vector3(0, 0.08, 0), Vector3.ZERO, "Skull", Vector3(0.93, 1.1, 1.0))
	_attach(head, _sphere(0.024, "skin"), Vector3(0, 0.065, -0.108), Vector3.ZERO, "Nose", Vector3(0.75, 1.2, 1.0))
	_attach(head, _box(Vector3(0.04, 0.008, 0.01), "mouth"), Vector3(0, 0.025, -0.104), Vector3.ZERO, "Mouth")
	for side: float in [-1.0, 1.0]:
		_attach(head, _sphere(0.016, "eye_white"), Vector3(0.038 * side, 0.095, -0.094))
		_attach(head, _sphere(0.01, "eye"), Vector3(0.038 * side, 0.095, -0.106))
		_attach(head, _box(Vector3(0.042, 0.011, 0.012), "beard_color" if appearance["beard"] else "hair"),
				Vector3(0.04 * side, 0.122, -0.1), Vector3(0, 0, -0.12 * side))
		var ear := _pivot(head, "LeftEar" if side < 0 else "RightEar", Vector3(0.105 * side, 0.08, 0.005),
				"l_ear" if side < 0 else "r_ear")
		_attach(ear, _sphere(0.026, "skin"), Vector3.ZERO, Vector3.ZERO, "", Vector3(0.45, 1.0, 0.75))
	if appearance["beard"]:
		_attach(head, _sphere(0.08, "beard_color"), Vector3(0, 0.0, -0.065), Vector3.ZERO, "Beard", Vector3(1.1, 1.3, 0.8))
		_attach(head, _box(Vector3(0.075, 0.016, 0.02), "beard_color"), Vector3(0, 0.042, -0.11), Vector3.ZERO, "Moustache")


func _build_hair(head: Node3D) -> void:
	match appearance["hair_style"]:
		"bald":
			# A crown of hair around the back and sides.
			_attach(head, _sphere(0.116, "hair"), Vector3(0, 0.06, 0.025), Vector3.ZERO, "HairRing", Vector3(0.98, 0.5, 0.98))
		"hood":
			_attach(head, _sphere(0.138, "tunic"), Vector3(0, 0.1, 0.02), Vector3.ZERO, "Hood", Vector3(1.0, 1.05, 1.08))
		_:
			_attach(head, _sphere(0.12, "hair"), Vector3(0, 0.11, 0.014), Vector3.ZERO, "Hair", Vector3(1.0, 0.82, 1.03))
			if appearance["hair_style"] == "long":
				_attach(head, _capsule(0.1, 0.32, "hair"), Vector3(0, -0.01, 0.07), Vector3.ZERO, "LongHair",
						Vector3(1.1, 1.0, 0.5))
			elif appearance["hair_style"] == "bun":
				_attach(head, _sphere(0.05, "hair"), Vector3(0, 0.17, 0.085), Vector3.ZERO, "Bun")
			elif appearance["hair_style"] == "twin_buns":
				# Two buns high on either side, wrapped in accent ribbon.
				for side: float in [-1.0, 1.0]:
					_attach(head, _sphere(0.048, "hair"), Vector3(0.082 * side, 0.18, 0.03), Vector3.ZERO,
							"LeftBun" if side < 0 else "RightBun")
					_attach(head, _torus(0.036, 0.05, "accent"), Vector3(0.07 * side, 0.165, 0.028),
							Vector3(0, 0, 0.75 * side), "", Vector3(1.0, 0.6, 1.0))
