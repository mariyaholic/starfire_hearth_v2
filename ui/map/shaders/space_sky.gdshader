shader_type sky;
uniform float visual_time = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123); }
float noise3(vec3 p) {
	vec3 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	float a = sin(dot(i,vec3(12.98,78.23,37.72)));
	float b = sin(dot(i+vec3(1,0,0),vec3(12.98,78.23,37.72)));
	float c = sin(dot(i+vec3(0,1,0),vec3(12.98,78.23,37.72)));
	float d = sin(dot(i+vec3(1,1,0),vec3(12.98,78.23,37.72)));
	float e = sin(dot(i+vec3(0,0,1),vec3(12.98,78.23,37.72)));
	float g = sin(dot(i+vec3(1,0,1),vec3(12.98,78.23,37.72)));
	float h = sin(dot(i+vec3(0,1,1),vec3(12.98,78.23,37.72)));
	float j = sin(dot(i+vec3(1,1,1),vec3(12.98,78.23,37.72)));
	return mix(mix(mix(a,b,f.x),mix(c,d,f.x),f.y),mix(mix(e,g,f.x),mix(h,j,f.x),f.y),f.z)*0.5+0.5;
}
void sky() {
	vec3 ray = normalize(EYEDIR);
	float band = pow(max(0.0, 1.0-abs(dot(ray, normalize(vec3(0.3,0.82,0.3))))), 10.0);
	float dust = noise3(ray*7.0) * noise3(ray*21.0);
	vec3 color = vec3(0.012,0.019,0.030) + vec3(0.20,0.23,0.31)*band*dust;
	vec2 grid = SKY_COORDS*vec2(1500.0,750.0);
	vec2 cell = floor(grid);
	float h = hash(cell);
	vec2 point = vec2(hash(cell+vec2(7,11)),hash(cell+vec2(19,5)));
	float star = (1.0-smoothstep(0.015,0.10,length(fract(grid)-point))) * step(0.976,h);
	color += mix(vec3(0.56,0.72,1.0),vec3(1.0,0.88,0.72),hash(cell+8.0)) * star * (0.20+hash(cell+23.0)*0.9);
	vec2 bright_grid = SKY_COORDS*vec2(430.0,215.0);
	vec2 bright_cell = floor(bright_grid);
	vec2 bright_point = vec2(hash(bright_cell+vec2(27,31)),hash(bright_cell+vec2(49,15)));
	float bright_star = exp(-length(fract(bright_grid)-bright_point)*22.0) * step(0.991,hash(bright_cell+51.0));
	color += vec3(0.52,0.63,0.76) * bright_star * (0.91 + 0.09*sin(visual_time*0.28 + hash(bright_cell)*6.28));
	COLOR = color;
}
