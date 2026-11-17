#version 460 core

// PMREMGenerator's PMREMGGXIntegration for the rough levels: every texel of a small source level weighted by
// the GGX lobe (V = N), pairing opposite texels so only the one in N's hemisphere contributes.
#include "shaders/face.glsl"

uniform IntegrationInfo {
	float roughness;
	float source_lod;
	float source_size;
} integration_info;

uniform samplerCube source;

out vec4 frag_color;

void main() {
	vec3 N = normalize(faceDirection());
	float alpha = integration_info.roughness * integration_info.roughness;
	float alpha2 = alpha * alpha;
	int sourceSize = int(integration_info.source_size + 0.5);
	float texelSize = 2.0 / float(sourceSize);
	vec3 prefilteredColor = vec3(0.0);
	float totalWeight = 0.0;

	for (int face = 0; face < 3; face++) {
		for (int y = 0; y < sourceSize; y++) {
			for (int x = 0; x < sourceSize; x++) {
				vec2 uv = (vec2(x, y) + 0.5) * texelSize - 1.0;
				vec3 texelDirection = face == 0 ? vec3(1.0, uv) : (face == 1 ? vec3(uv.x, 1.0, uv.y) : vec3(uv, 1.0));
				float invDistance = inversesqrt(1.0 + dot(uv, uv));
				float NdotL = dot(N, texelDirection);
				texelDirection *= NdotL < 0.0 ? -1.0 : 1.0;
				NdotL = abs(NdotL) * invDistance;

				// With V = N, NdotH squared is (1 + NdotL) / 2; factors common to the GGX distribution and the
				// texel solid angle cancel when normalized.
				float d = 1.0 + alpha2 + (alpha2 - 1.0) * NdotL;
				float weight = NdotL * invDistance * invDistance * invDistance / (d * d);
				prefilteredColor += textureLod(source, texelDirection, integration_info.source_lod).rgb * weight;
				totalWeight += weight;
			}
		}
	}

	frag_color = vec4(prefilteredColor / totalWeight, 1.0);
}
