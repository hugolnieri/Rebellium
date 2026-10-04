shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// Contorno por casco invertido: empurra a malha pela normal e desenha só as faces de trás.
uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.035, 1.0);
uniform float thickness = 0.0045;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
