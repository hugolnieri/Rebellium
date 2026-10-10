shader_type spatial;
// Prédios distantes: fachada escura com grade de janelas acesas (emissivas).
render_mode specular_disabled;

uniform vec4 wall : source_color = vec4(0.03, 0.035, 0.05, 1.0);
uniform float floor_height = 3.5;
uniform float column_width = 2.5;
uniform float density = 0.3;
uniform float brightness = 2.5;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float h = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
	vec2 g = vec2(h / column_width, world_pos.y / floor_height);
	vec2 c = floor(g);
	vec2 f = fract(g);
	float lit = step(1.0 - density, hash(c + floor(world_pos.xz * 0.01) * 13.0)) * step(0.25, f.x) * step(f.x, 0.75)
		* step(0.3, f.y) * step(f.y, 0.75) * step(abs(world_normal.y), 0.5);
	vec3 tint = hash(c + 7.0) < 0.7 ? vec3(1.0, 0.75, 0.45) : vec3(0.3, 0.8, 1.0);
	ALBEDO = wall.rgb;
	ROUGHNESS = 0.7;
	EMISSION = tint * lit * brightness;
}
