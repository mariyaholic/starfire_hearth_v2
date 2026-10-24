shader_type spatial;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_depth = 0.45;
void fragment() {
	vec3 surface = texture(surface_map, UV).rgb;
	ALBEDO = texture(albedo_map, UV).rgb;
	ROUGHNESS = surface.b;
	SPECULAR = mix(0.6, 0.28, surface.g);
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}
