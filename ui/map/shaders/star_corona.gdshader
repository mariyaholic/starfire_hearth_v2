shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float visual_time = 0.0;
void vertex() {
	// A plane through the stellar center always faces the observer. The opaque
	// photosphere occludes its middle; outside the limb it fades into space.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 at = (UV - 0.5) * 2.0;
	float radius = length(at);
	float angle = atan(at.y, at.x);
	float rays = 0.73 + 0.16*sin(angle*17.0 + sin(angle*7.0 + visual_time*0.13)) + 0.11*sin(angle*39.0 - visual_time*0.09);
	float falloff = exp(-max(0.0, radius-0.64)*21.0) * (1.0-smoothstep(0.86,1.0,radius));
	ALBEDO = vec3(1.0,0.46,0.13);
	ALPHA = falloff * rays * 0.62;
}
