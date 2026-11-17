#version 460 core

// BlurMaterial's fragment stage (the reference's separable blur material of its bloom pass). The number of tap pairs
// (3 to 11 for kernel radii 6 to 22) is a uniform and bounds a loop of at most MAX_KERNEL_PAIRS; the pairs' offsets
// and weights are packed four to a vec4.
#include "shaders/effect.glsl"

#define MAX_KERNEL_PAIRS 11

uniform FragInfo {
	vec2 inv_size;
	vec2 direction;
	float center_weight;
	float kernel_pairs;
	vec4 gaussian_offsets[(MAX_KERNEL_PAIRS + 3) / 4];
	vec4 gaussian_weights[(MAX_KERNEL_PAIRS + 3) / 4];

	// 1 when color_texture is a render target's texture.
	float flip;
} frag_info;

uniform sampler2D color_texture;

// colorTexture at WebGL's uv.
vec3 sampleColor(vec2 uv) {
	return texture(color_texture, effectUv(uv, frag_info.flip)).rgb;
}

void main() {
	vec3 diffuseSum = sampleColor(v_uv) * frag_info.center_weight;

	for (int i = 0; i < MAX_KERNEL_PAIRS; i++) {
		if (i >= int(frag_info.kernel_pairs)) {
			break;
		}

		vec2 uvOffset = frag_info.direction * frag_info.inv_size * frag_info.gaussian_offsets[i / 4][i % 4];
		vec3 sample1 = sampleColor(v_uv + uvOffset);
		vec3 sample2 = sampleColor(v_uv - uvOffset);
		diffuseSum += (sample1 + sample2) * frag_info.gaussian_weights[i / 4][i % 4];
	}

	frag_color = vec4(diffuseSum, 1.0);
}
