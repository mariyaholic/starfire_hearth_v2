shader_type spatial;
render_mode unshaded;
uniform sampler2D photosphere : filter_linear_mipmap, repeat_enable;
uniform vec3 star_color : source_color = vec3(1.0, 0.58, 0.24);
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void fragment() {
	float surface = texture(photosphere, UV).r;
	float detail = hash(floor(local_position * 380.0));
	float limb = pow(max(0.0, dot(normalize(NORMAL), normalize(VIEW))), 0.36);
	ALBEDO = star_color * mix(0.28, 1.18, pow(surface, 0.60)) * (0.73 + 0.27 * limb) * (0.98 + detail * 0.02);
}
