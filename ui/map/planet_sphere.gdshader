shader_type canvas_item;

// A planet as a lit sphere (§8.3): a painted-looking surface from 3D noise on the sphere (so it
// has no seams), a soft terminator from a light at the upper left, a rim light and an atmosphere
// glow. Everything comes from the type, the four palette colours and the seed.
// kind: 0 continental, 1 ocean, 2 arid, 3 ice, 4 barren, 5 toxic, 6 gas giant.

uniform int kind = 0;
uniform vec4 c0 : source_color = vec4(0.18, 0.44, 0.68, 1.0);
uniform vec4 c1 : source_color = vec4(0.31, 0.69, 0.42, 1.0);
uniform vec4 c2 : source_color = vec4(0.56, 0.82, 0.56, 1.0);
uniform vec4 c3 : source_color = vec4(0.92, 0.95, 0.97, 1.0);
uniform float seed = 0.0;
// Glow strength outside the disc and haze on its lit edge, 0 to 1.
uniform float atmosphere = 0.5;
uniform vec4 glow : source_color = vec4(0.55, 0.8, 1.0, 1.0);
// The disc's radius as a fraction of the rect, leaving room for the glow (and rings).
uniform float radius = 0.44;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

// The palette as a smooth ramp: 0 is c0, 1 is c3.
vec3 ramp(float t) {
	t = clamp(t, 0.0, 1.0) * 3.0;
	if (t < 1.0) {
		return mix(c0.rgb, c1.rgb, t);
	}
	if (t < 2.0) {
		return mix(c1.rgb, c2.rgb, t - 1.0);
	}
	return mix(c2.rgb, c3.rgb, t - 2.0);
}

vec3 surface(vec3 n, vec3 q) {
	if (kind == 6) {
		// Gas giant: bands along the latitude, stirred by turbulence, and one storm.
		float turb = fbm(q * vec3(1.6, 0.5, 1.6));
		float band = fract(n.y * 2.6 + turb * 0.8 + seed * 0.37);
		vec3 col = ramp(band);
		vec3 storm_at = normalize(vec3(sin(seed * 1.3), 0.25 * cos(seed * 2.1), cos(seed * 1.3)));
		float storm = smoothstep(0.93, 0.975, dot(n, storm_at));
		return mix(col, c3.rgb * 0.9 + c0.rgb * 0.1, storm * 0.8);
	}
	float h = fbm(q);
	if (kind == 0 || kind == 1) {
		// Continental and ocean: seas in c0, land in c1 and c2, ice caps and clouds in c3.
		float sea = kind == 0 ? 0.5 : 0.62;
		vec3 col = mix(c0.rgb * 0.75, c0.rgb, smoothstep(0.2, sea, h));
		col = mix(col, mix(c1.rgb, c2.rgb, smoothstep(sea, sea + 0.2, h)), smoothstep(sea - 0.01, sea + 0.01, h));
		float cap = smoothstep(0.8, 0.86, abs(n.y) + (noise(q * 3.0) - 0.5) * 0.12);
		col = mix(col, c3.rgb, cap);
		float cloud = smoothstep(0.55, 0.78, fbm(q * 1.6 + vec3(5.2, 1.3, 2.8)));
		return mix(col, vec3(0.96), cloud * (kind == 0 ? 0.55 : 0.7));
	}
	if (kind == 2) {
		// Arid: wind-laid dunes in bands.
		float dunes = fbm(q * vec3(1.0, 2.6, 1.0));
		return ramp(dunes * 0.85 + 0.05 * sin(n.y * 18.0 + seed));
	}
	if (kind == 3) {
		// Ice: pale fields cut by blue cracks.
		vec3 col = mix(c2.rgb, c3.rgb, smoothstep(0.35, 0.7, h));
		float ridge = 1.0 - abs(noise(q * 3.2) * 2.0 - 1.0);
		return mix(col, c0.rgb, smoothstep(0.9, 0.97, ridge) * 0.85);
	}
	if (kind == 4) {
		// Barren: grey plains and craters with bright rims.
		vec3 col = ramp(h * 0.75);
		float c = noise(q * 4.5);
		float rim = smoothstep(0.66, 0.69, c) - smoothstep(0.69, 0.74, c);
		col = mix(col, c0.rgb * 0.7, smoothstep(0.72, 0.8, c));
		return mix(col, c3.rgb, rim * 0.6);
	}
	// Toxic: swirling haze.
	float swirl = fbm(q + vec3(fbm(q * 1.3) * 1.8));
	return ramp(swirl);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) / radius;
	p.y = -p.y;
	float d = length(p);
	vec3 light = normalize(vec3(-0.55, 0.5, 0.67));
	float aa = max(fwidth(d) * 1.5, 0.002);
	vec4 col = vec4(0.0);
	if (d < 1.0 + aa) {
		float z = sqrt(max(0.0, 1.0 - d * d));
		vec3 n = vec3(p, z);
		vec3 q = n * 2.2 + vec3(seed * 0.113, seed * 0.271, seed * 0.157);
		vec3 surf = surface(n, q);
		// A soft terminator, lifted a little on the night side, in gentle painted steps.
		float lam = dot(n, light);
		float lit = smoothstep(-0.3, 0.85, lam);
		lit = mix(lit, floor(lit * 4.0 + 0.5) / 4.0, 0.25);
		vec3 shaded = surf * (0.14 + 0.92 * lit) + vec3(0.02, 0.03, 0.06) * (1.0 - lit);
		// Haze and a rim light on the lit edge.
		float edge = pow(1.0 - z, 2.5);
		shaded = mix(shaded, glow.rgb, edge * atmosphere * clamp(lam + 0.35, 0.0, 1.0) * 0.8);
		shaded += c3.rgb * pow(1.0 - z, 6.0) * clamp(lam + 0.2, 0.0, 1.0) * 0.35;
		col = vec4(shaded, 1.0 - smoothstep(1.0 - aa, 1.0, d));
	}
	if (atmosphere > 0.0 && d > 1.0 - aa) {
		// The glow outside the disc, brighter towards the light.
		vec2 dir = normalize(p);
		float side = clamp(dot(dir, normalize(light.xy)) * 0.5 + 0.6, 0.0, 1.0);
		float g = (1.0 - smoothstep(1.0, 1.16, d)) * atmosphere * side * 0.55;
		col = vec4(mix(glow.rgb, col.rgb, col.a), max(col.a, g));
	}
	COLOR = col;
}
