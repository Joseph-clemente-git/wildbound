class_name ArenaBuilder
extends RefCounted
## Builds a trial ground from ArenaData: a ring of standing stones, banners,
## obstacles, onlookers and the surrounding valley (mechanics §55-57).


static func build(parent: Node3D, arena: ArenaData) -> Node3D:
	var root := Node3D.new()
	root.name = "ArenaWorld"
	parent.add_child(root)
	WorldBuilder.environment(root, arena.mood)
	WorldBuilder.ground(root, 220.0, {"ring_center": Vector2.ZERO, "ring_radius": arena.radius + 0.3,
			"grass_a": arena.ground_color_a.darkened(0.2), "grass_b": arena.ground_color_b.darkened(0.15)})
	var clear: Array = [Vector3(0, 0, arena.radius + 1.5)]
	WorldBuilder.grass(root, Rect2(-40, -40, 80, 80), 4200, clear, 21)
	WorldBuilder.mountains(root, 100.0, 12, 9)
	WorldBuilder.forest_ring(root, arena.radius + 9.0, 45.0, 60, 13, false)
	# Standing stones mark the boundary.
	var stones := 18
	for i in stones:
		var angle := TAU * i / stones
		var spot := Vector3(cos(angle), 0, sin(angle)) * (arena.radius + 0.7)
		var height := 1.4 + 0.5 * float(i % 3)
		var stone := WorldBuilder.box(root, Vector3(0.6, height, 0.45), WorldBuilder.STONE, spot + Vector3(0, height * 0.5, 0))
		stone.rotation.y = -angle
	# Banners at the four quarters.
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		var spot := Vector3(cos(angle), 0, sin(angle)) * (arena.radius + 1.8)
		WorldBuilder.cylinder(root, 0.06, 4.0, WorldBuilder.WOOD_DARK, spot + Vector3(0, 2.0, 0))
		var cloth := WorldBuilder.box(root, Vector3(0.9, 1.6, 0.04), arena.banner_color, spot + Vector3(0, 3.0, 0))
		cloth.rotation.y = -angle + PI * 0.5
	# Deep water: a calm, slightly sunken pool with a pale shoreline.
	for zone: Vector3 in arena.water_zones:
		var shore := WorldBuilder.cylinder(root, zone.z + 0.25, 0.04, Color("c8b88a"), Vector3(zone.x, 0.01, zone.y), -1.0, 40)
		shore.name = "Shore"
		var water := WorldBuilder.cylinder(root, zone.z, 0.06, Color(0.22, 0.45, 0.62), Vector3(zone.x, 0.03, zone.y), -1.0, 40)
		water.name = "Water"
		var material := water.material_override as StandardMaterial3D
		if material != null:
			material = material.duplicate()
			material.roughness = 0.08
			material.metallic = 0.3
			water.material_override = material
	# Obstacles inside the ring (kept so the camera can fade them when they block the view).
	var obstacle_nodes: Array[GeometryInstance3D] = []
	for obstacle: Vector4 in arena.obstacles:
		var spot := Vector3(obstacle.x, 0, obstacle.y)
		if obstacle.w > 1.5:
			var pillar := WorldBuilder.cylinder(root, obstacle.z, obstacle.w, WorldBuilder.STONE_DARK,
					spot + Vector3(0, obstacle.w * 0.5, 0), obstacle.z * 0.8, 7)
			pillar.rotation.y = obstacle.x
			obstacle_nodes.append(pillar)
		else:
			obstacle_nodes.append(WorldBuilder.rock(root, spot + Vector3(0, obstacle.w * 0.3, 0), obstacle.z * 1.1, int(obstacle.x * 10)))
	for node in obstacle_nodes:
		# Own material per obstacle so it can fade without affecting others.
		node.material_override = (node.material_override as StandardMaterial3D).duplicate()
	root.set_meta("obstacles", obstacle_nodes)
	_onlookers(root, arena)
	return root


## A few champions of the valley and their Keepers watch from outside the ring.
static func _onlookers(root: Node3D, arena: ArenaData) -> void:
	var palettes := [
		{"fur": Color("6b4a2e"), "fur_light": Color("d8c0a0"), "scarf": Color("4f7a3a")},
		{"fur": Color("d0d0d0"), "fur_light": Color("ffffff"), "scarf": Color("7a3a6a")},
		{"fur": Color("2e2a28"), "fur_light": Color("8a8070"), "scarf": Color("c08a30")},
		{"fur": Color("c28a50"), "fur_light": Color("f5e0c0"), "scarf": Color("3a5a8a")},
	]
	for i in palettes.size():
		var angle := PI * 0.85 + i * 0.32
		var spot := Vector3(cos(angle), 0, sin(angle)) * (arena.radius + 3.2)
		var watcher := ProceduralDogVisual.new(palettes[i])
		watcher.position = spot
		watcher.rotation.y = atan2(spot.x, spot.z)
		watcher.scale = Vector3.ONE * 0.92
		root.add_child(watcher)
		if i % 2 == 0:
			watcher.play("victory", 1.2 + i * 0.1, false)
	# Their Keepers watch beside them.
	var keepers := [
		{"skin": Color("c49a74"), "hair": Color("2a1c14"), "tunic": Color("4f6b8a"), "hair_style": "short", "beard": true},
		{"skin": Color("f0c9a4"), "hair": Color("8a5a30"), "tunic": Color("7a4a5a"), "hair_style": "long"},
	]
	for i in keepers.size():
		var angle := PI * 0.85 + (i + 0.5) * 0.64
		var spot := Vector3(cos(angle), 0, sin(angle)) * (arena.radius + 4.3)
		var keeper := ProceduralHumanVisual.new(keepers[i])
		keeper.position = spot
		keeper.rotation.y = atan2(spot.x, spot.z)
		root.add_child(keeper)
