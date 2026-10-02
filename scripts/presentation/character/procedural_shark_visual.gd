class_name ProceduralSharkVisual
extends ProceduralDogVisual
## Humanoid shark on the shared humanoid rig: a long pointed head with a
## pale jaw and rows of teeth, gill flaps on the ear bones, a dorsal fin on
## the back and a crescent tail fin. Palette keys match the dog's, so lodge
## colours, armor and weapons work unchanged.

const SHARK_PALETTE := {
	"fur": Color("6d7f8c"),
	"fur_light": Color("e4e9ec"),
	"fur_dark": Color("3c4a55"),
	"eye": Color("101418"),
	"scarf": Color("2f6f9a"),
	"cloth": Color("2e3f4a"),
}


func _init(initial_palette: Dictionary = {}) -> void:
	var colours := SHARK_PALETTE.duplicate()
	colours.merge(initial_palette, true)
	super(colours)


func _build_materials() -> void:
	super()
	_materials["tooth"] = _make_material(Color("f6f2ea"), 0.4)
	_materials["gill"] = _make_material(Color("4a5a66"), 0.8)


func _build_head(head: Node3D) -> void:
	_attach(head, _sphere(0.16, "fur"), Vector3(0, 0.06, 0.02), Vector3.ZERO, "Skull", Vector3(0.95, 0.85, 1.25))
	_attach(head, _capsule(0.1, 0.34, "fur"), Vector3(0, 0.06, -0.2), Vector3(PI * 0.5, 0, 0), "Snout", Vector3(1.0, 0.8, 1.0))
	_attach(head, _capsule(0.085, 0.28, "fur_light"), Vector3(0, -0.04, -0.18), Vector3(PI * 0.5, 0, 0), "Jaw", Vector3(1.05, 0.6, 1.0))
	for i in 5:
		var x := -0.06 + i * 0.03
		_attach(head, _sphere(0.012, "tooth"), Vector3(x, -0.0, -0.27 + absf(x) * 0.6))
	for side: float in [-1.0, 1.0]:
		_attach(head, _sphere(0.026, "eye"), Vector3(0.095 * side, 0.09, -0.12))
		_attach(head, _sphere(0.008, "eye_shine"), Vector3(0.1 * side, 0.1, -0.135))
		# Gill flaps ride the ear bones so every clip still animates them.
		var gill := _pivot(head, "LeftEar" if side < 0 else "RightEar",
				Vector3(0.13 * side, 0.0, 0.08), "l_ear" if side < 0 else "r_ear")
		for slit in 3:
			_attach(gill, _box(Vector3(0.012, 0.09, 0.02), "gill"), Vector3(0, 0.0, slit * 0.035), Vector3(0, 0, 0.15 * side))


func _build_tail(tail: Node3D) -> void:
	_attach(tail, _capsule(0.08, 0.3, "fur"), Vector3(0, 0, 0.14), Vector3(PI * 0.5, 0, 0))
	_attach(tail, _capsule(0.055, 0.22, "fur"), Vector3(0, 0.02, 0.34), Vector3(PI * 0.5, 0, 0))
	var upper := PrismMesh.new()
	upper.size = Vector3(0.04, 0.32, 0.18)
	_attach(tail, _mesh(upper, "fur_dark"), Vector3(0, 0.16, 0.48), Vector3(-0.5, 0, 0), "TailFin")
	var lower := PrismMesh.new()
	lower.size = Vector3(0.04, 0.22, 0.14)
	_attach(tail, _mesh(lower, "fur_dark"), Vector3(0, -0.08, 0.46), Vector3(PI + 0.5, 0, 0), "TailFinLow")


func _build_extras(chest: Node3D, _hips: Node3D) -> void:
	var dorsal := PrismMesh.new()
	dorsal.size = Vector3(0.05, 0.3, 0.26)
	_attach(chest, _mesh(dorsal, "fur_dark"), Vector3(0, 0.22, 0.2), Vector3(-0.35, 0, 0), "DorsalFin")
	_attach(chest, _sphere(0.13, "fur_light"), Vector3(0, -0.02, -0.12), Vector3.ZERO, "Belly", Vector3(1.1, 1.3, 0.55))
