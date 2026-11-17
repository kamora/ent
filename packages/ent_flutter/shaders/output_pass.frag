#version 460 core

// OutputMaterial's fragment stage (the reference's OutputShader): the tone mapping and sRGB transfer of
// shaders/output.glsl, switched by uniforms (OutputInfo's tone_mapping: the material's tone mapping constant, 0 for
// none; output_srgb: whether its output color space has the sRGB transfer).
#include "shaders/output.glsl"
#include "shaders/common.glsl"
#include "shaders/effect.glsl"

uniform FragInfo {

	// 1 when t_diffuse is a render target's texture.
	float flip;
} frag_info;

uniform sampler2D t_diffuse;

void main() {
	frag_color = texture(t_diffuse, effectUv(v_uv, frag_info.flip));

	// tone mapping
	if (output_info.tone_mapping > 0.5) {
		frag_color.rgb = toneMapping(frag_color.rgb);
	}

	// color space
	if (output_info.output_srgb > 0.5) {
		frag_color = sRGBTransferOETF(frag_color);
	}
}
