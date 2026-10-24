shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never,shadows_disabled;
uniform float visual_time = 0.0;
varying float age;
void vertex() {
	age = fract(visual_time*0.12+INSTANCE_CUSTOM.r);
	vec4 at = MODEL_MATRIX[3];
	at.y += age*2.6;
	at.x += age*0.65;
	float size = (0.35+age*0.75);
	MODELVIEW_MATRIX = VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*size,INV_VIEW_MATRIX[1]*size,INV_VIEW_MATRIX[2]*size,at);
}
void fragment() {
	float radial = max(0.0,1.0-length((UV-0.5)*2.0));
	ALBEDO = vec3(0.77,0.79,0.78);
	ALPHA = pow(radial,2.6)*sin(age*3.14159)*0.10;
}
