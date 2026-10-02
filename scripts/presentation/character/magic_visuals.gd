class_name MagicVisuals
extends RefCounted
## Colours and simple particle effects for the Aether Arts schools.

const SCHOOL_COLORS := {
	"fire": Color("ff8a3d"),
	"frost": Color("9fe0ff"),
	"wind": Color("b8f0c8"),
	"earth": Color("c49a5a"),
	"lightning": Color("f5e66b"),
	"nature": Color("7ed36b"),
}


static func school_color(school: String) -> Color:
	return SCHOOL_COLORS.get(school, UiTheme.AETHER)


## One-shot burst of glowing motes. Frees itself when finished.
static func burst(parent: Node3D, at: Vector3, school: String, amount: int = 24,
		spread: float = 1.0, lifetime: float = 0.6) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.9
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 1.0 * spread
	particles.initial_velocity_max = 3.0 * spread
	particles.gravity = Vector3(0, -2.0, 0) if school != "fire" else Vector3(0, 1.5, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = school_color(school)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = ramp
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


## Continuous flickering flame (campfires, braziers, fire auras).
static func flame(at: Vector3, size: float = 0.3, school: String = "fire") -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.position = at
	particles.amount = 28
	particles.lifetime = 0.7
	particles.direction = Vector3.UP
	particles.spread = 18.0
	particles.gravity = Vector3(0, 1.2, 0)
	particles.initial_velocity_min = 0.4
	particles.initial_velocity_max = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = size * 0.6
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.35
	mesh.height = size * 0.7
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	var ramp := Gradient.new()
	var base := school_color(school)
	ramp.set_color(0, Color(base.lightened(0.4), 0.95))
	ramp.set_color(1, Color(base.darkened(0.3), 0.0))
	particles.color_ramp = ramp
	return particles
