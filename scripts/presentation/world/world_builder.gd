class_name WorldBuilder
extends RefCounted
## Procedural low-poly world pieces for the Home Valley.
##
## Everything is built from primitive meshes so the game runs without external
## art. Scenes compose these pieces; replacing one with a Blender model later
## only means swapping the function body.

const WOOD := Color("7b5634")
const WOOD_DARK := Color("4f3622")
const ROOF := Color("8c3f2e")
const STONE := Color("8f8a80")
const STONE_DARK := Color("6a665e")
const LEAF := Color("3f6b2f")
const LEAF_LIGHT := Color("5c8a3a")
const PINE := Color("2f5233")
const SNOW := Color("eef2f5")
const MOUNTAIN := Color("6d7a86")
const WARM_LIGHT := Color("ffc977")

## Positions of the lodge's interactive stations (story §13-14).
const STATIONS := {
	"champion": Vector3(0, 0, 0),
	"training": Vector3(-7.5, 0, 0.5),
	"trainers": Vector3(-4.2, 0, -4.6),
	"equipment": Vector3(4.6, 0, -4.2),
	"aether": Vector3(7.5, 0, 1.0),
	"recovery": Vector3(-1.6, 0, -5.6),
	"journey": Vector3(-4.0, 0, 5.4),
}

static var _materials: Dictionary = {}


static func material(color: Color, roughness: float = 0.9, metallic: float = 0.0,
		emission: Color = Color.BLACK) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), roughness, metallic, emission.to_html()]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = metallic
		if emission != Color.BLACK:
			mat.emission_enabled = true
			mat.emission = emission
			mat.emission_energy_multiplier = 1.5
		_materials[key] = mat
	return _materials[key]


static func mesh_instance(mesh: Mesh, color: Color, parent: Node3D, position: Vector3,
		rotation: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE,
		mat: Material = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat if mat != null else material(color)
	instance.position = position
	instance.rotation = rotation
	instance.scale = scale
	parent.add_child(instance)
	return instance


static func box(parent: Node3D, size: Vector3, color: Color, position: Vector3,
		rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_instance(mesh, color, parent, position, rotation)


static func cylinder(parent: Node3D, radius: float, height: float, color: Color,
		position: Vector3, top_radius: float = -1.0, segments: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh_instance(mesh, color, parent, position)


static func sphere(parent: Node3D, radius: float, color: Color, position: Vector3,
		scale: Vector3 = Vector3.ONE, segments: int = 10) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 4)
	return mesh_instance(mesh, color, parent, position, Vector3.ZERO, scale)


# --- Atmosphere ----------------------------------------------------------------

static func environment(parent: Node3D, mood: String = "day") -> DirectionalLight3D:
	var sky_material := ProceduralSkyMaterial.new()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	match mood:
		"dusk":
			sky_material.sky_top_color = Color("3d5a80")
			sky_material.sky_horizon_color = Color("f2b38a")
			sky_material.ground_horizon_color = Color("b48a6a")
			sun.light_color = Color("ffc18a")
			sun.light_energy = 0.9
			sun.rotation_degrees = Vector3(-18, 35, 0)
		_:
			sky_material.sky_top_color = Color("6fa3d6")
			sky_material.sky_horizon_color = Color("d9e6e4")
			sky_material.ground_horizon_color = Color("a9b8a0")
			sun.light_color = Color("fff1d6")
			sun.light_energy = 0.95
			sun.rotation_degrees = Vector3(-42, 30, 0)
	sky_material.ground_bottom_color = Color("3e4a36")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45 if mood != "dusk" else 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = sky_material.sky_horizon_color
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.15
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	parent.add_child(sun)
	return sun


static func ground(parent: Node3D, size: float, params: Dictionary = {}) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://shaders/ground.gdshader")
	for key: String in params:
		shader_material.set_shader_parameter(key, params[key])
	return mesh_instance(mesh, Color.WHITE, parent, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, shader_material)


## Wind-swept grass. `keep_clear` is an Array of Vector3(x, z, radius) circles.
static func grass(parent: Node3D, area: Rect2, count: int, keep_clear: Array = [],
		seed_value: int = 1) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var blade := _blade_mesh()
	var transforms: Array[Transform3D] = []
	var attempts := 0
	while transforms.size() < count and attempts < count * 4:
		attempts += 1
		var x := rng.randf_range(area.position.x, area.end.x)
		var z := rng.randf_range(area.position.y, area.end.y)
		var blocked := false
		for circle: Vector3 in keep_clear:
			if Vector2(x - circle.x, z - circle.y).length() < circle.z:
				blocked = true
				break
		if blocked:
			continue
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.3))
		transforms.append(Transform3D(basis, Vector3(x, 0, z)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://shaders/grass.gdshader")
	instance.material_override = shader_material
	parent.add_child(instance)
	return instance


## A tuft of three crossed tapered blades.
static func _blade_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var angle := i * TAU / 3.0
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.05
		var lean := Vector3(-sin(angle), 0, cos(angle)) * 0.08
		var tip := Vector3(0, 0.55, 0) + lean
		tool.set_normal(Vector3.UP)
		tool.add_vertex(-side)
		tool.add_vertex(side)
		tool.add_vertex(tip)
	return tool.commit()


# --- Landscape -----------------------------------------------------------------

static func mountains(parent: Node3D, radius: float, count: int, seed_value: int = 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.1, 0.1)
		# Keep the camera-facing side (south, +Z) more open.
		var r := radius * rng.randf_range(0.9, 1.25) * (1.25 if sin(angle) > 0.6 else 1.0)
		var height := rng.randf_range(18.0, 34.0)
		var base := rng.randf_range(14.0, 22.0)
		var position := Vector3(cos(angle) * r, height * 0.5 - 1.0, sin(angle) * r)
		var peak := cylinder(parent, base, height, MOUNTAIN.darkened(rng.randf_range(0.0, 0.2)), position, 0.0, 7)
		peak.rotation.y = rng.randf() * TAU
		var cap_height := height * 0.28
		var cap := cylinder(parent, base * 0.28 * 1.02, cap_height, SNOW,
				position + Vector3(0, height * 0.5 - cap_height * 0.5, 0), 0.0, 7)
		cap.rotation.y = peak.rotation.y


static func hills(parent: Node3D, positions: Array, color: Color = Color("4d7238")) -> void:
	for hill: Vector4 in positions:
		sphere(parent, 1.0, color, Vector3(hill.x, -hill.w * 0.55, hill.y),
				Vector3(hill.z, hill.w, hill.z * 0.8), 12)


static func pine(parent: Node3D, position: Vector3, height: float = 4.0) -> Node3D:
	var tree := Node3D.new()
	tree.position = position
	parent.add_child(tree)
	cylinder(tree, 0.18, height * 0.3, WOOD_DARK, Vector3(0, height * 0.15, 0))
	for layer in 3:
		var layer_height := height * (0.5 - layer * 0.1)
		var radius := height * (0.32 - layer * 0.07)
		cylinder(tree, radius, layer_height, PINE.lightened(layer * 0.05),
				Vector3(0, height * (0.35 + layer * 0.2) + layer_height * 0.5 - 0.3, 0), 0.0, 8)
	return tree


static func oak(parent: Node3D, position: Vector3, size: float = 1.0) -> Node3D:
	var tree := Node3D.new()
	tree.position = position
	parent.add_child(tree)
	cylinder(tree, 0.22 * size, 2.2 * size, WOOD_DARK, Vector3(0, 1.1 * size, 0), 0.16 * size)
	sphere(tree, 1.3 * size, LEAF, Vector3(0, 2.8 * size, 0), Vector3(1, 0.85, 1))
	sphere(tree, 0.9 * size, LEAF_LIGHT, Vector3(0.7 * size, 3.2 * size, 0.3 * size))
	sphere(tree, 0.8 * size, LEAF, Vector3(-0.6 * size, 3.0 * size, -0.4 * size))
	return tree


static func rock(parent: Node3D, position: Vector3, size: float = 1.0, seed_value: int = 0) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stone := sphere(parent, size, STONE.darkened(rng.randf_range(0.0, 0.2)), position,
			Vector3(rng.randf_range(0.9, 1.4), rng.randf_range(0.5, 0.8), rng.randf_range(0.9, 1.3)), 7)
	stone.rotation.y = rng.randf() * TAU
	return stone


static func forest_ring(parent: Node3D, inner: float, outer: float, count: int,
		seed_value: int = 5, open_south: bool = true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var angle := rng.randf() * TAU
		if open_south and absf(angle - PI * 0.5) < 0.62:
			continue  # leave the valley road clear
		var r := rng.randf_range(inner, outer)
		var position := Vector3(cos(angle) * r, 0, sin(angle) * r)
		if rng.randf() < 0.6:
			pine(parent, position, rng.randf_range(3.5, 6.5))
		else:
			oak(parent, position, rng.randf_range(0.8, 1.3))


static func fence(parent: Node3D, from: Vector3, to: Vector3, posts: int) -> void:
	for i in posts:
		var t := float(i) / maxf(posts - 1, 1)
		cylinder(parent, 0.07, 1.0, WOOD, from.lerp(to, t) + Vector3(0, 0.5, 0), -1.0, 6)
	var mid := (from + to) * 0.5
	var length := from.distance_to(to)
	var yaw := atan2(to.x - from.x, to.z - from.z)
	for rail_y: float in [0.45, 0.8]:
		var rail := box(parent, Vector3(0.06, 0.08, length), WOOD, mid + Vector3(0, rail_y, 0))
		rail.rotation.y = yaw


# --- Lodge pieces ----------------------------------------------------------------

static func lodge_building(parent: Node3D, position: Vector3) -> Node3D:
	var lodge := Node3D.new()
	lodge.name = "LodgeBuilding"
	lodge.position = position
	parent.add_child(lodge)
	box(lodge, Vector3(8.4, 0.4, 5.6), STONE_DARK, Vector3(0, 0.2, 0))
	box(lodge, Vector3(8.0, 3.0, 5.0), WOOD, Vector3(0, 1.9, 0))
	for x: float in [-3.9, 3.9]:
		for z: float in [-2.4, 2.4]:
			box(lodge, Vector3(0.35, 3.2, 0.35), WOOD_DARK, Vector3(x, 1.9, z))
	var roof := PrismMesh.new()
	roof.size = Vector3(9.2, 2.6, 6.4)
	mesh_instance(roof, ROOF, lodge, Vector3(0, 4.7, 0))
	box(lodge, Vector3(0.9, 2.2, 0.9), STONE, Vector3(2.6, 5.3, -1.0))
	# Door, windows with warm interior light, porch.
	box(lodge, Vector3(1.4, 2.2, 0.12), WOOD_DARK, Vector3(0, 1.5, 2.52))
	var glow := material(WARM_LIGHT, 0.6, 0.0, WARM_LIGHT)
	for x: float in [-2.6, 2.6]:
		var window := box(lodge, Vector3(1.2, 1.0, 0.1), WARM_LIGHT, Vector3(x, 2.0, 2.53))
		window.material_override = glow
		box(lodge, Vector3(1.4, 0.12, 0.2), WOOD_DARK, Vector3(x, 1.45, 2.58))
	box(lodge, Vector3(8.4, 0.2, 2.2), WOOD_DARK, Vector3(0, 0.45, 3.6))
	for x: float in [-3.9, 0.0, 3.9]:
		box(lodge, Vector3(0.22, 2.6, 0.22), WOOD_DARK, Vector3(x, 1.75, 4.55))
	box(lodge, Vector3(8.6, 0.25, 2.4), ROOF.darkened(0.15), Vector3(0, 3.15, 3.55),
			Vector3(deg_to_rad(-12), 0, 0))
	lantern(lodge, Vector3(-1.2, 2.6, 4.4))
	lantern(lodge, Vector3(1.2, 2.6, 4.4))
	# Hanging sign
	box(lodge, Vector3(2.4, 0.6, 0.08), WOOD, Vector3(0, 3.6, 2.6))
	return lodge


static func lantern(parent: Node3D, position: Vector3, energy: float = 1.2) -> OmniLight3D:
	sphere(parent, 0.12, WARM_LIGHT, position, Vector3.ONE, 8).material_override = \
			material(WARM_LIGHT, 0.5, 0.0, WARM_LIGHT)
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = WARM_LIGHT
	light.light_energy = energy
	light.omni_range = 5.0
	parent.add_child(light)
	return light


static func training_yard(parent: Node3D, center: Vector3) -> Node3D:
	var yard := Node3D.new()
	yard.name = "TrainingYard"
	yard.position = center
	parent.add_child(yard)
	for offset: Vector3 in [Vector3(-1.2, 0, -1.0), Vector3(1.2, 0, -0.6)]:
		training_dummy(yard, offset)
	fence(yard, Vector3(-3, 0, -2.5), Vector3(3, 0, -2.5), 5)
	fence(yard, Vector3(-3, 0, -2.5), Vector3(-3, 0, 2.5), 5)
	# Weapon rack
	box(yard, Vector3(1.6, 0.12, 0.2), WOOD_DARK, Vector3(0.3, 1.3, -2.2))
	for x: float in [-0.3, 0.3, 0.9]:
		box(yard, Vector3(0.05, 1.2, 0.05), Color("b8bec2"), Vector3(x, 0.9, -2.1),
				Vector3(deg_to_rad(8), 0, 0))
	return yard


static func training_dummy(parent: Node3D, position: Vector3) -> Node3D:
	var dummy := Node3D.new()
	dummy.position = position
	parent.add_child(dummy)
	cylinder(dummy, 0.08, 1.8, WOOD, Vector3(0, 0.9, 0))
	box(dummy, Vector3(1.0, 0.1, 0.1), WOOD, Vector3(0, 1.35, 0))
	sphere(dummy, 0.32, Color("c9b07a"), Vector3(0, 1.25, 0), Vector3(1, 1.3, 1))
	sphere(dummy, 0.2, Color("c9b07a"), Vector3(0, 1.85, 0))
	return dummy


static func equipment_bench(parent: Node3D, position: Vector3) -> Node3D:
	var bench := Node3D.new()
	bench.name = "EquipmentBench"
	bench.position = position
	parent.add_child(bench)
	box(bench, Vector3(2.4, 0.15, 1.0), WOOD, Vector3(0, 0.9, 0))
	for x: float in [-1.0, 1.0]:
		for z: float in [-0.35, 0.35]:
			box(bench, Vector3(0.12, 0.9, 0.12), WOOD_DARK, Vector3(x, 0.45, z))
	var sword := WeaponVisuals.build("sword")
	sword.position = Vector3(-0.4, 1.0, 0)
	sword.rotation = Vector3(PI * 0.5, 0.3, 0)
	bench.add_child(sword)
	var hammer := WeaponVisuals.build("hammer")
	hammer.position = Vector3(0.6, 1.0, 0.1)
	hammer.rotation = Vector3(PI * 0.5, -0.6, 0)
	bench.add_child(hammer)
	# Anvil
	box(bench, Vector3(0.6, 0.5, 0.4), STONE_DARK, Vector3(1.8, 0.25, 0.3))
	box(bench, Vector3(0.8, 0.2, 0.35), Color("5a5f63"), Vector3(1.8, 0.6, 0.3))
	return bench


static func magic_circle(parent: Node3D, position: Vector3) -> Node3D:
	var circle := Node3D.new()
	circle.name = "AetherCircle"
	circle.position = position
	parent.add_child(circle)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.5
	ring.outer_radius = 1.7
	ring.rings = 32
	var glow := material(UiTheme.AETHER, 0.4, 0.0, UiTheme.AETHER)
	var ring_instance := mesh_instance(ring, UiTheme.AETHER, circle, Vector3(0, 0.03, 0), Vector3.ZERO,
			Vector3(1, 0.15, 1), glow)
	ring_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 6:
		var angle := TAU * i / 6.0
		var stone := box(circle, Vector3(0.35, 1.3 + (i % 2) * 0.4, 0.3), STONE,
				Vector3(cos(angle) * 2.2, 0.65, sin(angle) * 2.2))
		stone.rotation.y = -angle
		var school: String = GameEnums.MAGIC_SCHOOLS[i]
		sphere(circle, 0.1, MagicVisuals.school_color(school),
				Vector3(cos(angle) * 2.2, 1.55 + (i % 2) * 0.4, sin(angle) * 2.2)).material_override = \
				material(MagicVisuals.school_color(school), 0.4, 0.0, MagicVisuals.school_color(school))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.8, 0)
	light.light_color = UiTheme.AETHER
	light.light_energy = 0.8
	light.omni_range = 4.0
	circle.add_child(light)
	return circle


static func notice_board(parent: Node3D, position: Vector3, paper: Color = Color("efe2c4"),
		node_name: String = "NoticeBoard") -> Node3D:
	var board := Node3D.new()
	board.name = node_name
	board.position = position
	parent.add_child(board)
	for x: float in [-0.9, 0.9]:
		box(board, Vector3(0.15, 2.2, 0.15), WOOD_DARK, Vector3(x, 1.1, 0))
	box(board, Vector3(2.0, 1.2, 0.1), WOOD, Vector3(0, 1.5, 0))
	box(board, Vector3(2.2, 0.15, 0.3), ROOF, Vector3(0, 2.2, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(node_name)
	for i in 4:
		var note := box(board, Vector3(0.38, 0.45, 0.02), paper,
				Vector3(-0.6 + i * 0.4, 1.5 + rng.randf_range(-0.2, 0.2), 0.07))
		note.rotation.z = rng.randf_range(-0.15, 0.15)
	return board


static func rest_area(parent: Node3D, position: Vector3) -> Node3D:
	var rest := Node3D.new()
	rest.name = "RestArea"
	rest.position = position
	parent.add_child(rest)
	box(rest, Vector3(1.6, 0.3, 2.2), Color("d8b45a"), Vector3(0, 0.15, 0))
	box(rest, Vector3(1.4, 0.08, 1.4), Color("6b8fb0"), Vector3(0, 0.34, 0.3))
	sphere(rest, 0.3, Color("efe2c4"), Vector3(0, 0.4, -0.75), Vector3(1.4, 0.5, 0.8))
	# Water bowl
	cylinder(rest, 0.25, 0.12, STONE, Vector3(1.2, 0.06, 0.6), 0.3)
	return rest


static func campfire(parent: Node3D, position: Vector3) -> OmniLight3D:
	for i in 6:
		var angle := TAU * i / 6.0
		rock(parent, position + Vector3(cos(angle) * 0.5, 0.08, sin(angle) * 0.5), 0.16, i)
	for i in 3:
		var log_mesh := box(parent, Vector3(0.12, 0.12, 0.7), WOOD_DARK, position + Vector3(0, 0.1, 0))
		log_mesh.rotation.y = i * PI / 3.0
	var light := OmniLight3D.new()
	light.position = position + Vector3(0, 0.6, 0)
	light.light_color = Color("ff9a4d")
	light.light_energy = 1.6
	light.omni_range = 6.0
	parent.add_child(light)
	parent.add_child(MagicVisuals.flame(position + Vector3(0, 0.15, 0), 0.35))
	return light


## Full Home Valley: ground, grass, forest, mountains, lodge and stations.
static func home_valley(parent: Node3D, mood: String = "day") -> Node3D:
	var world := Node3D.new()
	world.name = "HomeValley"
	parent.add_child(world)
	environment(world, mood)
	ground(world, 260.0, {"path_width": 2.2, "path_x": 1.0, "path_z_max": 120.0,
			"ring_center": Vector2(0, 0), "ring_radius": 4.5})
	var clear: Array = [Vector3(0, -8, 6.5), Vector3(0, 0, 4.8), Vector3(-7.5, 0.5, 3.4),
			Vector3(7.5, 1.0, 2.6), Vector3(4.6, -4.2, 2.0), Vector3(-4.2, -4.6, 1.8), Vector3(-4.0, 5.4, 1.6)]
	for z in range(0, 60, 2):
		clear.append(Vector3(1.0 + sin(z * 0.35) * 0.6, z, 1.6))
	grass(world, Rect2(-28, -24, 56, 64), 5200, clear, 11)
	hills(world, [Vector4(-30, -30, 18, 6), Vector4(28, -26, 16, 5), Vector4(-36, 10, 14, 4),
			Vector4(38, 12, 15, 5)])
	mountains(world, 95.0, 14)
	forest_ring(world, 20.0, 42.0, 70)
	lodge_building(world, Vector3(0, 0, -11))
	training_yard(world, STATIONS["training"])
	equipment_bench(world, STATIONS["equipment"])
	magic_circle(world, STATIONS["aether"])
	notice_board(world, STATIONS["trainers"], Color("efe2c4"), "TrainerBoard")
	notice_board(world, STATIONS["journey"], Color("d9c48f"), "MapBoard")
	rest_area(world, STATIONS["recovery"])
	campfire(world, Vector3(3.6, 0, 1.6))
	for i in 8:
		rock(world, Vector3(-14 + i * 4.1, 0.2, 9 + (i % 3) * 3.0), 0.5 + (i % 3) * 0.2, i)
	return world
