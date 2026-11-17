#version 460 core

// ShaderLib.backgroundCube's fragment stage: the cube map (or, with backgroundBlurriness, the PMREM level of that
// roughness) along the rotated direction, times backgroundIntensity, tone mapped (when its color space is not
// sRGB) and encoded in the output color space; no fog.
#include "shaders/output.glsl"

uniform FragInfo {

	// backgroundRotation, transposed and mirrored in x for a cube texture that is not a render target.
	mat4 rotation;
	float blurriness;
	float intensity;

	// 1 for ENVMAP_TYPE_PMREM, with ENVMAP_MAX_LOD.
	float pmrem;
	float max_lod;
} frag_info;

uniform samplerCube env_map;

layout(location = 0) in vec3 v_world_direction;

out vec4 frag_color;

float roughnessToMip(float roughness) {
	float r = clamp(roughness, 0.0, 1.0);
	return frag_info.max_lod * r * (2.0 - r);
}

void main() {
	vec3 direction = mat3(frag_info.rotation) * v_world_direction;
	vec4 texColor = frag_info.pmrem > 0.5
		? textureLod(env_map, direction, roughnessToMip(frag_info.blurriness))
		: texture(env_map, direction);
	texColor.rgb *= frag_info.intensity;
	frag_color = finishColor(texColor, 0.0);
}
