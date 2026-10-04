shader_type spatial;
// Toon estilo anime: sombra em degrau com borda suave, sombra colorida (não preta), luz de borda
// e emissão por textura (linhas do traje). O CharacterModel cria variantes trocando o render_mode.
render_mode cull_back, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D emission_tex : source_color, hint_default_black, filter_linear_mipmap;
uniform vec4 emission_tint : source_color = vec4(1.0);
uniform float emission_energy = 0.0;
// Sombra: cor multiplicada na área sem luz, limiar e suavidade do degrau.
uniform vec4 shade_color : source_color = vec4(0.62, 0.58, 0.72, 1.0);
uniform float shade_threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.06;
// 0 = sem sombra (rosto), 1 = sombra completa.
uniform float shading_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 rim_color : source_color = vec4(0.75, 0.78, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float rim_power : hint_range(0.5, 16.0) = 4.0;
// Brilho de técnica/troca de arma (somado ao corpo inteiro).
uniform vec4 flash_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * tint;
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power) * rim_strength;
	EMISSION = texture(emission_tex, UV).rgb * emission_tint.rgb * emission_energy
		+ rim_color.rgb * rim * tex.rgb + flash_color.rgb;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndl);
	lit *= smoothstep(0.3, 0.7, ATTENUATION);
	lit = mix(1.0, lit, shading_strength);
	DIFFUSE_LIGHT += mix(shade_color.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI;
}
