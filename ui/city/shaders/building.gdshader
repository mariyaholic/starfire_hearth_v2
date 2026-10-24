shader_type spatial;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.8);
uniform float metallic = 0.0;
uniform float roughness_scale = 1.0;
varying vec3 location;
void vertex() { location = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 tiled = UV*2.0;
	float seam = min(min(fract(UV.x*4.0),1.0-fract(UV.x*4.0)),min(fract(UV.y*4.0),1.0-fract(UV.y*4.0)));
	float panel = mix(0.67,1.0,smoothstep(0.004,0.016,seam));
	ALBEDO = texture(albedo_map,tiled).rgb * tint * panel;
	METALLIC = metallic;
	ROUGHNESS = clamp(texture(roughness_map,tiled).r*roughness_scale,0.19,0.98);
	NORMAL_MAP = texture(normal_map,tiled).rgb;
	NORMAL_MAP_DEPTH = 0.32;
}
