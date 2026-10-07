shader_type spatial;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_roughness : filter_linear_mipmap, repeat_enable;
varying vec3 location;
varying vec3 world_normal;
void vertex() { location=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
	vec2 tiled=location.xz*0.37;
	float slope=1.0-abs(world_normal.y);
	float strata=0.5+0.5*sin(location.y*6.0+texture(rock_roughness,tiled*0.18).r*5.0);
	float stone=smoothstep(0.08,0.38,slope)+strata*0.16;
	stone=clamp(stone,0.0,1.0);
	vec3 grain=mix(texture(soil_albedo,tiled).rgb,texture(rock_albedo,tiled).rgb,stone);
	// Macro patches remain visible when the mip chain filters subpixel grain.
	// World coordinates keep both scales continuous across regional tile seams.
	vec3 luma=vec3(0.2126,0.7152,0.0722);
	float patch=dot(texture(soil_albedo,location.xz*0.035).rgb,luma);
	float variation=(dot(grain,luma)-mix(0.3403,0.4302,stone))*3.5+(patch-0.3403)*5.0;
	ALBEDO=pow(COLOR.rgb,vec3(2.2))*clamp(0.98+variation,0.68,1.30);
	ROUGHNESS=mix(texture(soil_roughness,tiled).r,texture(rock_roughness,tiled).r,clamp(stone,0.0,1.0));
	vec2 micro=mix(texture(soil_normal,tiled).xy,texture(rock_normal,tiled).xy,clamp(stone,0.0,1.0))*2.0-1.0;
	// The regional meshes have world-space biomes and no tangent array.
	NORMAL=normalize((VIEW_MATRIX*vec4(normalize(world_normal+vec3(micro.x,0.0,micro.y)*0.40),0.0)).xyz);
	SPECULAR=0.18;
}
