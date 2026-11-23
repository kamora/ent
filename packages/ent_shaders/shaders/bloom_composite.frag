#version 460 core

// BloomMaterial's fragment stage (the reference's composite material of its bloom pass, 5 mips). The mip factors are
// packed four to a vec4, the tint colors one to a vec4.
#include "shaders/effect.glsl"

uniform FragInfo {
	float bloom_strength;
	float bloom_radius;
	vec4 bloom_factors[2];
	vec4 bloom_tint_colors[5];

	// 1 when the blur textures are render targets' textures.
	float flip;
} frag_info;

uniform sampler2D blur_texture1;
uniform sampler2D blur_texture2;
uniform sampler2D blur_texture3;
uniform sampler2D blur_texture4;
uniform sampler2D blur_texture5;

float lerpBloomFactor(const in float factor) {
	float mirrorFactor = 1.2 - factor;
	return mix(factor, mirrorFactor, frag_info.bloom_radius);
}

void main() {
	vec2 uv = effectUv(v_uv, frag_info.flip);

	// 3.0 for backwards compatibility with previous alpha-based intensity
	vec3 bloom = 3.0 * frag_info.bloom_strength * (
		lerpBloomFactor(frag_info.bloom_factors[0].x) * frag_info.bloom_tint_colors[0].rgb * texture(blur_texture1, uv).rgb +
		lerpBloomFactor(frag_info.bloom_factors[0].y) * frag_info.bloom_tint_colors[1].rgb * texture(blur_texture2, uv).rgb +
		lerpBloomFactor(frag_info.bloom_factors[0].z) * frag_info.bloom_tint_colors[2].rgb * texture(blur_texture3, uv).rgb +
		lerpBloomFactor(frag_info.bloom_factors[0].w) * frag_info.bloom_tint_colors[3].rgb * texture(blur_texture4, uv).rgb +
		lerpBloomFactor(frag_info.bloom_factors[1].x) * frag_info.bloom_tint_colors[4].rgb * texture(blur_texture5, uv).rgb
	);

	float bloomAlpha = max(bloom.r, max(bloom.g, bloom.b));
	frag_color = vec4(bloom, bloomAlpha);
}
