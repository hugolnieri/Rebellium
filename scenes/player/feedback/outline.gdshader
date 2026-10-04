shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// Contorno por casco invertido: empurra a malha pela normal e desenha só as faces de trás.
// Respeita o alfa da textura (mechas de cabelo recortadas não viram retângulos pretos).
uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.035, 1.0);
uniform float thickness = 0.0045;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform float alpha_cut = 0.5;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = texture(albedo_tex, UV).a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}
