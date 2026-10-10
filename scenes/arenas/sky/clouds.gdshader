shader_type spatial;
// Camada de nuvens abaixo da plataforma: ruído que se move com o vento, borda some ao longe.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(0.5, 0.56, 0.7, 1.0);
uniform vec4 city_tint : source_color = vec4(0.55, 0.35, 0.7, 1.0);
uniform float scale = 0.004;
uniform vec2 wind = vec2(0.004, 0.0015);
uniform float coverage = 0.42;
uniform float softness = 0.28;
uniform float opacity = 0.85;
uniform float fade_radius = 900.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale;
	float n = texture(noise_tex, p + TIME * wind).r * 0.65 + texture(noise_tex, p * 2.7 - TIME * wind * 1.7).r * 0.35;
	float a = smoothstep(coverage, coverage + softness, n);
	float edge = 1.0 - smoothstep(0.3, 1.0, length(world_pos.xz) / fade_radius);
	ALBEDO = mix(color.rgb * 0.55, color.rgb, n) + city_tint.rgb * 0.18 * (1.0 - n);
	ALPHA = a * opacity * edge;
}
