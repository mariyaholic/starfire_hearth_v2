shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform float visual_time = 0.0;
void vertex() { VERTEX.x+=sin(visual_time*1.7+VERTEX.y*5.0+INSTANCE_CUSTOM.x*8.0)*0.007; }
void fragment() {
	float vein=1.0-smoothstep(0.012,0.055,abs(UV.x-0.5));
	float ribs=pow(0.5+0.5*cos((UV.y+abs(UV.x-0.5)*0.55)*95.0),16.0);
	ALBEDO=texture(albedo_map,UV).rgb*COLOR.rgb*(0.86+vein*0.23+ribs*0.11);
	ROUGHNESS=texture(roughness_map,UV).r;
	NORMAL_MAP=texture(normal_map,UV).rgb; NORMAL_MAP_DEPTH=0.22;
	BACKLIGHT=ALBEDO*0.12;
}
