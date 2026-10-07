shader_type spatial;
render_mode blend_mix, depth_draw_never, shadows_disabled;
uniform sampler2D cloud_map : filter_linear_mipmap, repeat_enable;
uniform vec3 cloud_color : source_color = vec3(0.94, 0.96, 0.97);
void fragment() {
	float density = texture(cloud_map, UV).r;
	ALBEDO = cloud_color;
	ROUGHNESS = 1.0;
	ALPHA = density * density * 0.68;
}
