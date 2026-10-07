shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_texture : filter_linear, repeat_disable;
uniform bool has_scene = false;
uniform vec4 scene_rect = vec4(0.0,0.0,1.0,1.0);
uniform vec2 scene_pixel = vec2(0.001);
uniform vec2 panel_size = vec2(300.0,200.0);
uniform vec4 tint : source_color = vec4(0.075,0.15,0.23,1.0);
uniform float opacity = 0.82;
uniform float blur = 8.0;
uniform float gloss = 0.10;
uniform float edge_light = 0.15;
void fragment() {
	vec2 p = UV * panel_size;
	vec2 half_size = panel_size * 0.5;
	vec2 q = abs(p-half_size) - half_size + vec2(8.0);
	float distance_to_edge = length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0) - 8.0;
	float mask = 1.0-smoothstep(-1.0,0.0,distance_to_edge);
	vec3 background = tint.rgb;
	if (has_scene && opacity < 1.0) {
		vec2 scene_uv = (SCREEN_UV-scene_rect.xy)/max(scene_rect.zw,vec2(0.001));
		vec2 offset = scene_pixel * blur;
		background = texture(scene_texture,scene_uv).rgb * 0.25;
		background += texture(scene_texture,scene_uv+vec2(offset.x,0.0)).rgb * 0.125;
		background += texture(scene_texture,scene_uv-vec2(offset.x,0.0)).rgb * 0.125;
		background += texture(scene_texture,scene_uv+vec2(0.0,offset.y)).rgb * 0.125;
		background += texture(scene_texture,scene_uv-vec2(0.0,offset.y)).rgb * 0.125;
		background += texture(scene_texture,scene_uv+offset).rgb * 0.0625;
		background += texture(scene_texture,scene_uv-offset).rgb * 0.0625;
		background += texture(scene_texture,scene_uv+vec2(offset.x,-offset.y)).rgb * 0.0625;
		background += texture(scene_texture,scene_uv+vec2(-offset.x,offset.y)).rgb * 0.0625;
	}
	vec3 surface = mix(background,tint.rgb,opacity);
	float title_sheen = (1.0-smoothstep(0.0,45.0,p.y)) * gloss * 0.3;
	float rim = smoothstep(-2.0,-0.4,distance_to_edge) * edge_light;
	surface += vec3(0.40,0.65,0.78) * (title_sheen+rim);
	COLOR = vec4(surface,mask);
}
