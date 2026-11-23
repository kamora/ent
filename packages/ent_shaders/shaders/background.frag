#version 460 core

// ShaderLib.background's fragment stage: the texture times backgroundIntensity, tone mapped (when its color
// space is not sRGB) and encoded in the output color space; no fog.
#include "shaders/output.glsl"

uniform FragInfo {
	float intensity;
} frag_info;

uniform sampler2D map;

layout(location = 0) in vec2 v_uv;

out vec4 frag_color;

void main() {
	vec4 texColor = texture(map, v_uv);
	texColor.rgb *= frag_info.intensity;
	frag_color = finishColor(texColor, 0.0);
}
