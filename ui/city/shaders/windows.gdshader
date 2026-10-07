shader_type spatial;
uniform vec3 tint : source_color = vec3(0.9,0.62,0.30);
uniform float night_amount = 0.0;
void fragment() {
	ALBEDO = mix(vec3(0.025,0.05,0.065),tint*0.68,night_amount);
	EMISSION = tint*night_amount*1.3;
	METALLIC = 0.15;
	ROUGHNESS = 0.24;
}
