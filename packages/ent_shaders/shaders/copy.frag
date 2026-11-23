#version 460 core

// CopyMaterial's fragment stage (the reference's CopyShader).
#include "shaders/effect.glsl"

uniform FragInfo {
	float opacity;

	// 1 when t_diffuse is a render target's texture.
	float flip;
} frag_info;

uniform sampler2D t_diffuse;

void main() {
	vec4 texel = texture(t_diffuse, effectUv(v_uv, frag_info.flip));
	frag_color = frag_info.opacity * texel;
}
