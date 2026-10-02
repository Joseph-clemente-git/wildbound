class_name ArenaLayout
extends RefCounted
## An arena as the simulation sees it: a flat ring with circular obstacles
## and starting points for each team. Positions are planar (x, z) Vector2s;
## height above the ground is tracked by each combatant, so flying,
## elevation and water zones can be added here later without changing
## positions.

## Space kept between neighbouring teammates when an arena defines fewer
## spawn points than the format needs.
const TEAMMATE_SPACING := 2.2

var id := ""
var radius := 11.0
## Obstacles as (x, z, radius); `obstacle_heights` holds their heights.
var obstacles: Array[Vector3] = []
var obstacle_heights := PackedFloat32Array()
## Deep water as (x, z, radius) circles.
var water_zones: Array[Vector3] = []
## Height fliers may use; 0 means nobody flies here.
var air_ceiling := 6.0
## Spawn points per team: [team 0 points, team 1 points].
var spawns: Array = [[], []]


static func from_arena(arena: ArenaData) -> ArenaLayout:
	var layout := ArenaLayout.new()
	layout.id = arena.id
	layout.radius = arena.radius
	for obstacle: Vector4 in arena.obstacles:
		layout.obstacles.append(Vector3(obstacle.x, obstacle.y, obstacle.z))
		layout.obstacle_heights.append(obstacle.w)
	layout.water_zones = arena.water_zones.duplicate()
	layout.air_ceiling = arena.air_ceiling
	layout.spawns = [_planar(arena.player_spawns), _planar(arena.opponent_spawns)]
	for team in 2:
		if layout.spawns[team].is_empty():
			layout.spawns[team].append(Vector2(0.0, arena.radius * (0.45 if team == 0 else -0.45)))
	return layout


## Where the `slot`-th member of a team starts. Extra members line up
## beside the first spawn, alternating sides, facing the same way.
func spawn_point(team: int, slot: int) -> Vector2:
	var points: Array = spawns[clampi(team, 0, spawns.size() - 1)]
	if slot < points.size():
		return points[slot]
	var base: Vector2 = points[0]
	var toward_centre := -base.normalized() if base.length() > 0.01 else Vector2(0, -1)
	var side := Vector2(-toward_centre.y, toward_centre.x)
	var extra := slot - points.size() + 1
	var step := ceili(extra / 2.0) * TEAMMATE_SPACING
	return base + side * (step if extra % 2 == 1 else -step)


func in_water(point: Vector2) -> bool:
	for zone in water_zones:
		if point.distance_to(Vector2(zone.x, zone.y)) <= zone.z:
			return true
	return false


## The nearest point of water, or `point` itself when there is none.
func nearest_water(point: Vector2) -> Vector2:
	var best := point
	var best_distance := INF
	for zone in water_zones:
		var centre := Vector2(zone.x, zone.y)
		var distance := point.distance_to(centre) - zone.z
		if distance < best_distance:
			best_distance = distance
			best = centre
	return best


func contains(point: Vector2, body_radius: float = 0.0) -> bool:
	return point.length() <= radius - body_radius


## True when a body of `body_radius` at `point` overlaps no obstacle and
## stays inside the ring.
func is_open(point: Vector2, body_radius: float) -> bool:
	if not contains(point, body_radius):
		return false
	for obstacle in obstacles:
		if point.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z + body_radius:
			return false
	return true


static func _planar(points: Array[Vector3]) -> Array:
	var result: Array = []
	for point in points:
		result.append(Vector2(point.x, point.z))
	return result
