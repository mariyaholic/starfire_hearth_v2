shader_type spatial;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_depth = 0.55;
void fragment() {
	vec3 surface=texture(surface_map,UV).rgb;
	vec3 color=texture(albedo_map,UV).rgb;
	float water=1.0-smoothstep(0.18,0.52,surface.g);
	ALBEDO=color;
	ROUGHNESS=mix(clamp(surface.b,0.72,0.98),0.20,water);
	SPECULAR=mix(0.26,0.7,water);
	NORMAL_MAP=texture(normal_map,UV).rgb;
	NORMAL_MAP_DEPTH=normal_depth*(1.0-water*0.55);
}
