shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.18, 0.48, 0.7);
uniform float strength = 0.34;
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.5);
	ALBEDO = tint * strength * rim;
	ALPHA = rim * strength;
}
