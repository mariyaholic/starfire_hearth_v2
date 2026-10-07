shader_type spatial;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D trim_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D trim_ao : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float metallic = 0.0;
uniform float panel_amount = 1.0;
uniform float ao_strength : hint_range(0.0,1.0) = 0.45;
uniform bool solar = false;
void fragment() {
	vec2 tiled = UV*2.0;
	vec3 micro = texture(normal_map,tiled).rgb*2.0-1.0;
	vec3 panel = texture(trim_normal,UV).rgb*2.0-1.0;
	NORMAL_MAP = normalize(vec3(micro.xy*0.22+panel.xy*panel_amount*0.7,1.0))*0.5+0.5;
	float joint = texture(trim_ao,UV).r;
	float scratches = texture(roughness_map,tiled*3.0).r;
	ALBEDO = texture(albedo_map,tiled).rgb*tint*(0.94+scratches*0.08);
	if (solar) {
		vec2 cell = abs(fract(UV*vec2(12.0,8.0))-0.5);
		float seam = smoothstep(0.45,0.49,max(cell.x,cell.y));
		ALBEDO = mix(ALBEDO*0.75,vec3(0.18,0.23,0.24),seam);
	}
	ROUGHNESS = clamp(texture(roughness_map,tiled).r+scratches*0.12,solar?0.18:0.28,0.97);
	METALLIC = metallic;
	AO = mix(1.0,joint,ao_strength*panel_amount);
}
