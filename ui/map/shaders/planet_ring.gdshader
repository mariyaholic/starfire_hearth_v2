shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float radius = UV.x;
	float grains = 0.5+0.5*sin(radius*340.0 + sin(radius*103.0)*2.0);
	float bands = 0.5+0.5*sin(radius*73.0);
	float gap = smoothstep(0.010,0.026,abs(radius-0.63));
	float edge = smoothstep(0.0,0.015,radius)*(1.0-smoothstep(0.96,1.0,radius));
	ALBEDO = mix(vec3(0.24,0.20,0.16),vec3(0.68,0.60,0.49),bands*0.5+grains*0.5);
	ROUGHNESS = 0.97;
	ALPHA = (0.27 + bands*0.23 + grains*0.29) * gap * edge;
}
