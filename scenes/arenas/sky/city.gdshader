shader_type spatial;
// Cidade lá embaixo: quarteirões escuros com janelas acesas e avenidas iluminadas.
render_mode unshaded;

uniform float block = 14.0;
uniform float window = 2.2;
uniform float density = 0.12;
uniform float brightness = 1.4;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / block;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float road = step(0.88, max(f.x, f.y));
	vec2 q = world_pos.xz / window;
	vec2 qc = floor(q);
	vec2 qf = fract(q);
	float lit = step(1.0 - density, hash(qc)) * step(0.2, qf.x) * step(qf.x, 0.8) * step(0.2, qf.y) * step(qf.y, 0.8);
	float district = hash(cell * 0.37 + 1.7);
	vec3 light = district < 0.6 ? vec3(1.0, 0.7, 0.35) : (district < 0.82 ? vec3(0.2, 0.8, 1.0) : vec3(1.0, 0.3, 0.8));
	vec3 c = vec3(0.01, 0.012, 0.02);
	c += light * lit * (0.5 + hash(qc + 3.0)) * brightness * (1.0 - road);
	c += road * vec3(1.0, 0.75, 0.4) * 0.45 * step(0.55, hash(cell));
	ALBEDO = c;
}
