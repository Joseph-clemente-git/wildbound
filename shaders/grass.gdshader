shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Wind-swept grass blades for the valley. Instances come from a MultiMesh;
// the instance's world position offsets the wave so the field ripples.

uniform vec4 base_color : source_color = vec4(0.18, 0.34, 0.14, 1.0);
uniform vec4 tip_color : source_color = vec4(0.62, 0.72, 0.34, 1.0);
uniform float sway = 0.18;
uniform float blade_height = 0.55;
uniform float wind_speed = 1.6;

varying float height_ratio;

void vertex() {
	height_ratio = clamp(VERTEX.y / blade_height, 0.0, 1.0);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float gust = sin(TIME * wind_speed + origin.x * 0.35 + origin.z * 0.22) * 0.5 + 0.5;
	float flutter = sin(TIME * 4.3 + origin.x * 2.1 + origin.z * 1.7) * 0.25;
	float bend = (gust + flutter) * sway * height_ratio * height_ratio;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.45;
}

void fragment() {
	ALBEDO = mix(base_color.rgb, tip_color.rgb, height_ratio);
	ROUGHNESS = 0.9;
}
