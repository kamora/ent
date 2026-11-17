#version 460 core

// PMREMGenerator's PMREMEquirectangularToCubemap: four subpixel samples of the equirectangular texture, which
// preserve small bright features. The sum is symmetric in the derivatives' signs.
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
	vec3 direction = normalize(faceDirection());
	vec3 dx = dFdx(direction) * 0.25;
	vec3 dy = dFdy(direction) * 0.25;
	vec3 color = textureLod(source, equirectUv(normalize(direction - dx - dy)), 0.0).rgb;
	color += textureLod(source, equirectUv(normalize(direction + dx - dy)), 0.0).rgb;
	color += textureLod(source, equirectUv(normalize(direction - dx + dy)), 0.0).rgb;
	color += textureLod(source, equirectUv(normalize(direction + dx + dy)), 0.0).rgb;
	frag_color = vec4(color * 0.25, 1.0);
}
