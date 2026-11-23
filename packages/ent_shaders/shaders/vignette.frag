#version 460 core

// VignetteMaterial's fragment stage (the reference's VignetteShader).
#include "shaders/effect.glsl"

uniform FragInfo {
	float offset;
	float darkness;

	// 1 when t_diffuse is a render target's texture.
	float flip;
} frag_info;

uniform sampler2D t_diffuse;

void main() {
	// Eskil's vignette
	vec4 texel = texture(t_diffuse, effectUv(v_uv, frag_info.flip));
	vec2 uv = (v_uv - vec2(0.5)) * vec2(frag_info.offset);
	frag_color = vec4(mix(texel.rgb, vec3(1.0 - frag_info.darkness), dot(uv, uv)), texel.a);
}
