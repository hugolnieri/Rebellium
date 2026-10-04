shader_type canvas_item;
// Linhas de velocidade radiais nas bordas da tela. intensity 0..1 vem da velocidade do jogador.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float max_alpha : hint_range(0.0, 1.0) = 0.32;
uniform vec4 line_color : source_color = vec4(0.86, 0.84, 0.79, 1.0);
uniform float line_count = 110.0;
uniform float inner_radius = 0.32;
uniform float aspect = 1.777;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= aspect;
	float r = length(p) / (0.5 * length(vec2(aspect, 1.0)));
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float id = floor(a * line_count);
	// Cada linha sorteia presença e comprimento; o sorteio muda ~20x por segundo (cintila).
	float frame = floor(TIME * 20.0);
	float rnd = hash(id * 12.9898 + frame * 78.233);
	float present = step(1.0 - intensity * 0.55, rnd);
	float start = inner_radius + hash(id * 3.17 + frame) * 0.3 * (1.0 - intensity);
	float radial = smoothstep(start, start + 0.25, r);
	float across = 1.0 - abs(fract(a * line_count) - 0.5) * 2.0;
	float thin = smoothstep(0.55, 1.0, across);
	COLOR = vec4(line_color.rgb, line_color.a * max_alpha * intensity * present * radial * thin);
}
