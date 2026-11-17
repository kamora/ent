// MeshDepthMaterial's fragment stage (depth.glsl): the fragment's depth, 1 - z with opacity
// (BasicDepthPacking) or packed into RGBA, RGB or RG bytes (packing; the variant's DEPTH_PACKING_RGBA,
// DEPTH_PACKING_RGB or DEPTH_PACKING_RG), or itself in a shadow map. No tone mapping, color space
// conversion or fog; only the polygon offset (offset.glsl). The vertex stage passes the clip-space
// z and w (vHighPrecisionZW); Impeller's depth range is [0, 1], so z / w is already the depth WebGL computes
// as 0.5 * z / w + 0.5.
#include "shaders/offset.glsl"
#include "shaders/mesh_in.glsl"
#include "shaders/maps.glsl"

uniform FragInfo {
	float opacity;

	// 1 for a shadow map, which stores the fragment's depth itself (the reference reads the depth texture).
	float shadow;
} frag_info;

const float PackUpscale = 256. / 255.;
const float ShiftRight8 = 1. / 256.;
const float Inv255 = 1. / 255.;
const vec4 PackFactors = vec4(1.0, 256.0, 256.0 * 256.0, 256.0 * 256.0 * 256.0);

vec4 packDepthToRGBA(float v) {
	if (v <= 0.0) {
		return vec4(0., 0., 0., 0.);
	}

	if (v >= 1.0) {
		return vec4(1., 1., 1., 1.);
	}

	float vuf;
	float af = modf(v * PackFactors.a, vuf);
	float bf = modf(vuf * ShiftRight8, vuf);
	float gf = modf(vuf * ShiftRight8, vuf);
	return vec4(vuf * Inv255, gf * PackUpscale, bf * PackUpscale, af);
}

vec3 packDepthToRGB(float v) {
	if (v <= 0.0) {
		return vec3(0., 0., 0.);
	}

	if (v >= 1.0) {
		return vec3(1., 1., 1.);
	}

	float vuf;
	float bf = modf(v * PackFactors.b, vuf);
	float gf = modf(vuf * ShiftRight8, vuf);
	return vec3(vuf * Inv255, gf * PackUpscale, bf);
}

vec2 packDepthToRG(float v) {
	if (v <= 0.0) {
		return vec2(0., 0.);
	}

	if (v >= 1.0) {
		return vec2(1., 1.);
	}

	float vuf;
	float gf = modf(v * 256., vuf);
	return vec2(vuf * Inv255, gf);
}

out vec4 frag_color;

void main() {
	bool shadow = frag_info.shadow > 0.5;
	vec4 diffuseColor = vec4(1.0);

#if !defined(DEPTH_PACKING_RGBA) && !defined(DEPTH_PACKING_RGB) && !defined(DEPTH_PACKING_RG)
	if (!shadow) {
		diffuseColor.a = frag_info.opacity;
	}
#endif

	diffuseColor = diffuseOf(diffuseColor);

	float fragCoordZ = v_clip_zw[0] / v_clip_zw[1];

	if (shadow) {
		frag_color = vec4(gl_FragCoord.z, 0.0, 0.0, 1.0);
	} else {
#if defined(DEPTH_PACKING_RGBA)
		frag_color = packDepthToRGBA(fragCoordZ);
#elif defined(DEPTH_PACKING_RGB)
		frag_color = vec4(packDepthToRGB(fragCoordZ), 1.0);
#elif defined(DEPTH_PACKING_RG)
		frag_color = vec4(packDepthToRG(fragCoordZ), 0.0, 1.0);
#else
		frag_color = vec4(vec3(1.0 - fragCoordZ), frag_info.opacity);
#endif
	}

	applyPolygonOffset();
}
