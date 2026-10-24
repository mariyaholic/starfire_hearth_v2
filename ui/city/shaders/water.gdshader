shader_type spatial;
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform float extent = 112.0;
uniform float visual_time = 0.0;
uniform bool frozen = false;
uniform bool toxic = false;
varying vec3 location;
void vertex() { location = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float ground = texture(height_map,clamp(location.xz/(extent*2.0)+0.5,vec2(0.001),vec2(0.999))).r;
	float depth = clamp(-ground/3.5,0.0,1.0);
	float wave = sin(location.x*2.1+location.z*0.48+visual_time*0.55)*sin(location.z*3.2-visual_time*0.30);
	float wave_lod = 1.0-smoothstep(0.4,3.0,max(fwidth(location.x*2.1+location.z*0.48),fwidth(location.z*3.2)));
	wave *= wave_lod;
	float foam = (1.0-smoothstep(0.02,0.46,-ground))*smoothstep(0.23,0.85,wave*0.5+0.5);
	ALBEDO = mix(vec3(0.075,0.26,0.28),vec3(0.018,0.075,0.13),depth);
	ALBEDO = mix(ALBEDO,vec3(0.68,0.75,0.69),foam*0.38);
	if (toxic) { ALBEDO *= vec3(0.75,1.15,0.45); }
	ROUGHNESS = 0.24;
	SPECULAR = 0.68;
	NORMAL_MAP = normalize(vec3(cos(location.x*2.1+visual_time*0.55)*0.10*wave_lod,sin(location.z*3.2-visual_time*0.30)*0.08*wave_lod,1.0))*0.5+0.5;
	if (frozen) {
		ALBEDO = vec3(0.36,0.55,0.61)*(0.86+wave*0.06);
		ROUGHNESS = 0.61;
		NORMAL_MAP_DEPTH = 0.15;
	}
}
