#version 460 core

// WebGLCubeRenderTarget.fromEquirectangularTexture: the equirectangular texture along the face's direction.
// The reference samples with the texture's minFilter switched to LinearFilter, so only the base level is read.
#define PI 3.141592653589793
#define RECIPROCAL_PI 0.3183098861837907
#define RECIPROCAL_PI2 0.15915494309189535

#include "shaders/face.glsl"

uniform sampler2D source;

out vec4 frag_color;

vec2 equirectUv(vec3 dir) {
	float u = atan(dir.z, dir.x) * RECIPROCAL_PI2 + 0.5;
	float v = asin(clamp(dir.y, -1.0, 1.0)) * RECIPROCAL_PI + 0.5;
	return vec2(u, v);
}

void main() {
	frag_color = textureLod(source, equirectUv(normalize(faceDirection())), 0.0);
}
