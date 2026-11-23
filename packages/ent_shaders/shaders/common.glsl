// The reference's common chunk, the part the lit materials use: constants, IncidentLight, ReflectedLight,
// BRDF_Lambert and F_Schlick. Include after shaders/output.glsl, which defines saturate().
#define PI 3.141592653589793
#define PI2 6.283185307179586
#define RECIPROCAL_PI 0.3183098861837907
#define RECIPROCAL_PI2 0.15915494309189535
#define EPSILON 1e-6

float pow2(float x) {
	return x * x;
}

vec3 pow2(vec3 x) {
	return x * x;
}

float max3(vec3 v) {
	return max(max(v.x, v.y), v.z);
}

float pow4(float x) {
	float x2 = x * x;
	return x2 * x2;
}

struct IncidentLight {
	vec3 color;
	vec3 direction;
	bool visible;
};

struct ReflectedLight {
	vec3 directDiffuse;
	vec3 directSpecular;
	vec3 indirectDiffuse;
	vec3 indirectSpecular;
};

vec3 BRDF_Lambert(vec3 diffuseColor) {
	return RECIPROCAL_PI * diffuseColor;
}

vec3 F_Schlick(vec3 f0, float f90, float dotVH) {
	float fresnel = exp2((-5.55473 * dotVH - 6.98316) * dotVH);
	return f0 * (1.0 - fresnel) + (f90 * fresnel);
}

float F_Schlick(float f0, float f90, float dotVH) {
	float fresnel = exp2((-5.55473 * dotVH - 6.98316) * dotVH);
	return f0 * (1.0 - fresnel) + (f90 * fresnel);
}

vec2 equirectUv(vec3 dir) {
	float u = atan(dir.z, dir.x) * RECIPROCAL_PI2 + 0.5;
	float v = asin(clamp(dir.y, -1.0, 1.0)) * RECIPROCAL_PI + 0.5;
	return vec2(u, v);
}
