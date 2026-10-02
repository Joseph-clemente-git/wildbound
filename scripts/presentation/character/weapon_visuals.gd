class_name WeaponVisuals
extends RefCounted
## Primitive-mesh weapon models, attached to a hand pivot.
##
## The hand's local -Z is "forward" when the arm hangs down, so blades extend
## along -Z and swing naturally with the shared attack clips.

const STEEL := Color("c9d1d6")
const WOOD := Color("7a5230")
const GRIP := Color("3d2a1c")
const GOLD := Color("d6a648")


static func build(weapon_type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_" + weapon_type
	match weapon_type:
		"sword":
			_part(root, _box(Vector3(0.05, 0.012, 0.72), STEEL, 0.25, 0.8), Vector3(0, 0, -0.44))
			_part(root, _box(Vector3(0.2, 0.03, 0.04), GOLD, 0.4, 0.6), Vector3(0, 0, -0.08))
			_part(root, _cylinder(0.022, 0.16, GRIP), Vector3(0, 0, 0.0), Vector3(PI * 0.5, 0, 0))
			_part(root, _sphere(0.035, GOLD), Vector3(0, 0, 0.09))
		"hammer":
			_part(root, _cylinder(0.025, 0.85, WOOD), Vector3(0, 0, -0.3), Vector3(PI * 0.5, 0, 0))
			_part(root, _box(Vector3(0.16, 0.16, 0.3), Color("8b8f93"), 0.5, 0.6), Vector3(0, 0, -0.72), Vector3(0, PI * 0.5, 0))
			_part(root, _box(Vector3(0.18, 0.18, 0.05), GOLD, 0.4, 0.6), Vector3(0, 0, -0.72))
		"dagger":
			_part(root, _box(Vector3(0.04, 0.01, 0.32), STEEL, 0.25, 0.8), Vector3(0, 0, -0.24))
			_part(root, _box(Vector3(0.12, 0.02, 0.03), GOLD, 0.4, 0.6), Vector3(0, 0, -0.07))
			_part(root, _cylinder(0.018, 0.12, GRIP), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
		"spear":
			_part(root, _cylinder(0.022, 1.6, WOOD), Vector3(0, 0, -0.35), Vector3(PI * 0.5, 0, 0))
			_part(root, _cone(0.05, 0.24, STEEL), Vector3(0, 0, -1.26), Vector3(-PI * 0.5, 0, 0))
		"axe":
			_part(root, _cylinder(0.024, 0.75, WOOD), Vector3(0, 0, -0.26), Vector3(PI * 0.5, 0, 0))
			_part(root, _box(Vector3(0.03, 0.26, 0.2), STEEL, 0.3, 0.8), Vector3(0, 0.1, -0.56))
		"shield":
			_part(root, _cylinder(0.3, 0.05, WOOD, 0.3), Vector3(0.08, 0, -0.05), Vector3(0, 0, PI * 0.5))
			_part(root, _cylinder(0.08, 0.06, STEEL, 0.08), Vector3(0.12, 0, -0.05), Vector3(0, 0, PI * 0.5))
		"bow":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.5
			torus.outer_radius = 0.54
			var bow := _part(root, _with_material(torus, WOOD), Vector3(0.0, 0, 0.3), Vector3(0, 0, PI * 0.5))
			bow.scale = Vector3(1.0, 0.35, 1.0)
	return root


static func _part(parent: Node3D, instance: MeshInstance3D, offset: Vector3,
		rotation_euler: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	instance.position = offset
	instance.rotation = rotation_euler
	parent.add_child(instance)
	return instance


static func _material(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


static func _with_material(mesh: Mesh, color: Color, roughness: float = 0.8, metallic: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, roughness, metallic)
	return instance


static func _box(size: Vector3, color: Color, roughness: float = 0.8, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _with_material(mesh, color, roughness, metallic)


static func _cylinder(radius: float, height: float, color: Color, bottom: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius if bottom < 0.0 else bottom
	mesh.height = height
	mesh.radial_segments = 12
	return _with_material(mesh, color)


static func _cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return _with_material(mesh, color, 0.3, 0.8)


static func _sphere(radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _with_material(mesh, color, 0.4, 0.6)
