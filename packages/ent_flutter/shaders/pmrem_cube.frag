#version 460 core

// PMREMGenerator's PMREMCubemapToCubemap: the source cube map, mirrored in x unless it is a render target
// (flipEnvMap).
#include "shaders/face.glsl"

uniform CubeInfo {
	float flip;
} cube_info;

uniform samplerCube source;

out vec4 frag_color;

void main() {
	vec3 direction = faceDirection();
	frag_color = vec4(texture(source, vec3(cube_info.flip * direction.x, direction.yz)).rgb, 1.0);
}
