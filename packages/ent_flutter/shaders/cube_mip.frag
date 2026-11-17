#version 460 core

// One mip level of a cube map from the level above it (WebGL's generateMipmap): the centre of a texel here is
// the centre of a 2 × 2 block there, so a bilinear sample is the block's average (a box filter).
#include "shaders/face.glsl"

uniform MipInfo {
	float source_lod;
} mip_info;

uniform samplerCube source;

out vec4 frag_color;

void main() {
	frag_color = textureLod(source, faceDirection(), mip_info.source_lod);
}
