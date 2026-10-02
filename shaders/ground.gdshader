shader_type spatial;
render_mode specular_disabled;

// Ground with low-frequency colour variation and an optional dirt path/ring.

uniform vec4 grass_a : source_color = vec4(0.27, 0.43, 0.2, 1.0);
uniform vec4 grass_b : source_color = vec4(0.36, 0.5, 0.24, 1.0);
uniform vec4 dirt : source_color = vec4(0.5, 0.4, 0.27, 1.0);
// Path: a straight strip along Z at x = path_x (width 0 disables it).
uniform float path_width = 0.0;
uniform float path_x = 0.0;
uniform float path_z_max = 40.0;
// Ring: circular dirt area (radius 0 disables it).
uniform vec2 ring_center = vec2(0.0, 0.0);
uniform float ring_radius = 0.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = noise(p * 0.15) * 0.6 + noise(p * 0.8) * 0.4;
	vec3 color = mix(grass_a.rgb, grass_b.rgb, n);
	float dirt_amount = 0.0;
	if (path_width > 0.0) {
		float wobble = sin(p.y * 0.35) * 0.6;
		float d = abs(p.x - path_x - wobble);
		dirt_amount = max(dirt_amount, (1.0 - smoothstep(path_width * 0.5, path_width * 0.5 + 0.6, d)) * step(p.y, path_z_max));
	}
	if (ring_radius > 0.0) {
		float r = length(p - ring_center);
		dirt_amount = max(dirt_amount, 1.0 - smoothstep(ring_radius - 0.8, ring_radius + 0.4, r));
	}
	color = mix(color, dirt.rgb * (0.85 + 0.3 * noise(p * 2.0)), dirt_amount);
	ALBEDO = color;
	ROUGHNESS = 0.95;
}
