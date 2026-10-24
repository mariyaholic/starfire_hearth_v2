shader_type spatial;
render_mode cull_disabled;
uniform vec3 tint : source_color = vec3(0.23,0.36,0.21);
uniform float visual_time = 0.0;
varying vec3 location;
void vertex() {
	location=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.x += sin(location.x*1.7+location.z*0.8+visual_time*1.2)*0.014*(VERTEX.y+0.55);
}
void fragment() {
	float vein=exp(-abs(UV.x-0.5)*90.0);
	float ribs=pow(max(0.0,sin(UV.y*58.0+abs(UV.x-0.5)*26.0)),12.0)*0.09;
	ALBEDO=tint*COLOR.rgb*(0.88+UV.y*0.14+vein*0.13+ribs);
	ROUGHNESS=0.88;
	SPECULAR=0.16;
}
