#version 460 core

// One mip level of a 2D texture from the level above it (WebGL's generateMipmap), a box filter: the centre of a
// texel here is the centre of a 2 × 2 block there.
uniform MipInfo {
	float source_lod;

	// The size of the level being rendered.
	vec2 size;
} mip_info;

uniform sampler2D source;

out vec4 frag_color;

void main() {
	frag_color = textureLod(source, gl_FragCoord.xy / mip_info.size, mip_info.source_lod);
}
