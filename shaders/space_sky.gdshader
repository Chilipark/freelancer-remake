shader_type sky;
// Procedural space backdrop: two-colour nebula clouds plus a star field.

uniform vec3 nebula_a : source_color = vec3(0.25, 0.1, 0.4);
uniform vec3 nebula_b : source_color = vec3(0.05, 0.25, 0.45);
uniform float nebula_strength = 0.7;
uniform float star_amount = 0.012;
uniform float seed = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3) + seed);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
	               mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
	               mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float n = fbm(d * 2.5 + vec3(seed));
	float n2 = fbm(d * 5.0 - vec3(seed * 1.7));
	float cloud = pow(smoothstep(0.38, 0.85, n), 1.5);
	vec3 neb = mix(nebula_a, nebula_b, n2) * cloud * nebula_strength;

	vec3 p = d * 300.0;
	vec3 c = floor(p);
	vec3 f = fract(p) - 0.5;
	float h = hash(c);
	float star = 0.0;
	if (h > 1.0 - star_amount) {
		float b = (h - (1.0 - star_amount)) / star_amount;
		star = b * smoothstep(0.45, 0.0, length(f)) * 2.5;
	}
	vec3 star_col = mix(vec3(0.8, 0.85, 1.0), vec3(1.0, 0.85, 0.7), hash(c + 3.1));
	COLOR = vec3(0.004, 0.005, 0.012) + neb + star_col * star;
}
