#version 460 core

// HighPassMaterial's fragment stage (the reference's LuminosityHighPassShader).
#include "shaders/effect.glsl"

uniform FragInfo {
	vec3 default_color;
	float default_opacity;
	float luminosity_threshold;
	float smooth_width;

	// 1 when t_diffuse is a render target's texture.
	float flip;
} frag_info;

uniform sampler2D t_diffuse;

// The reference's luminance() with the working color space's (Linear sRGB) Rec. 709 coefficients, toFixed( 4 ).
float luminance(const in vec3 rgb) {
	const vec3 weights = vec3(0.2126, 0.7152, 0.0722);
	return dot(weights, rgb);
}

void main() {
	vec4 texel = texture(t_diffuse, effectUv(v_uv, frag_info.flip));

	float v = luminance(texel.xyz);

	vec4 outputColor = vec4(frag_info.default_color.rgb, frag_info.default_opacity);

	float alpha = smoothstep(frag_info.luminosity_threshold, frag_info.luminosity_threshold + frag_info.smooth_width, v);

	frag_color = mix(outputColor, texel, alpha);
}
