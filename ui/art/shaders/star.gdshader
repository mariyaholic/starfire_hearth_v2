shader_type spatial;
render_mode unshaded;
uniform sampler2D photosphere : filter_linear_mipmap, repeat_enable;
uniform vec3 star_color : source_color = vec3(1.0,0.58,0.24);
varying vec3 local_position;
void vertex() { local_position=VERTEX; }
void fragment() {
	float heat=texture(photosphere,UV).r;
	float granule=texture(photosphere,UV*vec2(7.0,5.0)).r;
	float limb=pow(max(0.0,dot(normalize(NORMAL),normalize(VIEW))),0.42);
	float brightness=mix(0.19,1.20,pow(heat,0.68))*(0.84+granule*0.22);
	vec3 hot=mix(star_color,vec3(1.0,0.91,0.74),smoothstep(0.58,0.88,heat)*0.33);
	ALBEDO=hot*brightness*(0.63+0.37*limb);
}
