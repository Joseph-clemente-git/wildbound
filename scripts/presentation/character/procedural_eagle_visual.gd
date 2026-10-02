class_name ProceduralEagleVisual
extends ProceduralDogVisual
## Humanoid eagle on the shared humanoid rig: a white feathered head with a
## hooked golden beak, crest feathers on the ear bones, broad wings on the
## back (the arms stay free for weapons) and a fan of tail feathers.

const EAGLE_PALETTE := {
	"fur": Color("5a3e26"),
	"fur_light": Color("f2efe6"),
	"fur_dark": Color("2f2014"),
	"eye": Color("2a1a08"),
	"scarf": Color("c08a30"),
	"cloth": Color("4a3a28"),
}

var wings: Array[Node3D] = []


func _init(initial_palette: Dictionary = {}) -> void:
	var colours := EAGLE_PALETTE.duplicate()
	colours.merge(initial_palette, true)
	super(colours)


func _build_materials() -> void:
	super()
	_materials["beak"] = _make_material(Color("e8b030"), 0.45)
	_materials["iris"] = _make_material(Color("e8c040"), 0.3)


func _build_head(head: Node3D) -> void:
	_attach(head, _sphere(0.15, "fur_light"), Vector3(0, 0.07, 0), Vector3.ZERO, "Skull", Vector3(0.95, 1.0, 1.1))
	_attach(head, _sphere(0.1, "fur_light"), Vector3(0, -0.02, 0.04), Vector3.ZERO, "Nape", Vector3(1.1, 1.0, 1.0))
	var beak := PrismMesh.new()
	beak.size = Vector3(0.09, 0.16, 0.1)
	_attach(head, _mesh(beak, "beak"), Vector3(0, 0.02, -0.2), Vector3(-PI * 0.5, 0, 0), "Beak", Vector3(1.0, 1.0, 0.9))
	_attach(head, _sphere(0.035, "beak"), Vector3(0, -0.03, -0.24), Vector3.ZERO, "BeakHook", Vector3(0.8, 1.0, 0.8))
	for side: float in [-1.0, 1.0]:
		_attach(head, _sphere(0.03, "iris"), Vector3(0.08 * side, 0.09, -0.11))
		_attach(head, _sphere(0.016, "eye"), Vector3(0.088 * side, 0.09, -0.125))
		_attach(head, _box(Vector3(0.06, 0.02, 0.05), "fur_dark"), Vector3(0.08 * side, 0.125, -0.1), Vector3(0, 0, 0.3 * side), "Brow")
		# Crest feathers ride the ear bones.
		var crest := _pivot(head, "LeftEar" if side < 0 else "RightEar",
				Vector3(0.05 * side, 0.18, 0.08), "l_ear" if side < 0 else "r_ear")
		var feather := PrismMesh.new()
		feather.size = Vector3(0.05, 0.14, 0.02)
		_attach(crest, _mesh(feather, "fur_light"), Vector3(0, 0.05, 0), Vector3(-0.6, 0, -0.2 * side))


func _build_tail(tail: Node3D) -> void:
	for i in 5:
		var spread := (i - 2) * 0.22
		var feather := PrismMesh.new()
		feather.size = Vector3(0.07, 0.34, 0.02)
		_attach(tail, _mesh(feather, "fur_dark" if i % 2 == 0 else "fur"), Vector3(sin(spread) * 0.08, -0.02, 0.2),
				Vector3(PI * 0.5 + 0.2, spread, 0))


func _build_extras(chest: Node3D, _hips: Node3D) -> void:
	_attach(chest, _sphere(0.14, "fur"), Vector3(0, 0.0, -0.1), Vector3.ZERO, "Breast", Vector3(1.1, 1.2, 0.6))
	for side: float in [-1.0, 1.0]:
		# A wing hinges at the shoulder blade: folded down the back at rest,
		# swung out wide while aloft (set_spread).
		var wing := Node3D.new()
		wing.name = "LeftWing" if side < 0 else "RightWing"
		wing.position = Vector3(0.12 * side, 0.16, 0.17)
		chest.add_child(wing)
		_attach(wing, _box(Vector3(0.2, 0.62, 0.035), "fur"), Vector3(0.1 * side, -0.27, 0.0), Vector3.ZERO, "Covert")
		for i in 3:
			var length := 0.55 - i * 0.1
			_attach(wing, _box(Vector3(0.12, length, 0.03), "fur_dark" if i % 2 == 0 else "fur"),
					Vector3((0.2 + i * 0.09) * side, -length * 0.5 - 0.05, 0.015 * (i + 1)), Vector3(0, 0, 0.12 * i * side), "Primary")
		_attach(wing, _box(Vector3(0.36, 0.12, 0.035), "fur_light"), Vector3(0.16 * side, 0.02, -0.005), Vector3.ZERO, "Shoulder")
		wings.append(wing)
	set_spread(0.0)


## Folds (0) or spreads (1) the wings — driven by height in the replay.
func set_spread(amount: float) -> void:
	for i in wings.size():
		var side := -1.0 if i == 0 else 1.0
		var folded := Vector3(0.18, 0.25 * side, 0.12 * side)
		var spread := Vector3(0.05, 0.1 * side, 1.35 * side)
		wings[i].rotation = folded.lerp(spread, clampf(amount, 0.0, 1.0))
