#version 460 core

// PMREMGenerator's PMREMGGXConvolution: the GGX lobe of the level's roughness integrated with visible-normal
// importance sampling (V = N), each sample reading the source mip level that matches its solid angle.
#define PI 3.141592653589793
#define GGX_SAMPLES 256

#include "shaders/face.glsl"

uniform GgxInfo {
	float roughness;

	// log2 of the texel solid angle terms that do not depend on the sample (PMREMGenerator._applyPMREM).
	float lod_bias;
} ggx_info;

uniform samplerCube source;

out vec4 frag_color;

// The Van der Corput radical inverse of i < 256: its bits mirrored, here with float arithmetic (exact for these
// values; the reference uses uint bit operations, which impellerc cannot translate for every backend).
float radicalInverse_VdC(float i) {
	float result = 0.0;
	float weight = 0.5;

	for (int k = 0; k < 8; k++) {
		float half_ = floor(i * 0.5);

		if (i - half_ * 2.0 > 0.5) {
			result += weight;
		}

		i = half_;
		weight *= 0.5;
	}

	return result;
}

// The Hammersley sequence.
vec2 hammersley(float i, float N) {
	return vec2(i / N, radicalInverse_VdC(i));
}

// The prefiltered radiance around [N] for [roughness] (above 0.001).
vec3 convolve(vec3 N, float roughness) {
	float alpha = roughness * roughness;
	float alpha2 = alpha * alpha;

	// The tangent space basis for VNDF sampling.
	vec3 up = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(up, N));
	vec3 bitangent = cross(N, tangent);
	vec3 prefilteredColor = vec3(0.0);
	float totalWeight = 0.0;

	for (int i = 0; i < GGX_SAMPLES; i++) {
		vec2 Xi = hammersley(float(i), float(GGX_SAMPLES));

		// With V = N, the reflected direction is sampled directly.
		float invQ = 1.0 / (1.0 - Xi.x + alpha2 * Xi.x);
		float NdotL = (1.0 - Xi.x - alpha2 * Xi.x) * invQ;

		if (NdotL > 0.0) {
			float phi = 2.0 * PI * Xi.y;
			float sinTheta = 2.0 * alpha * sqrt(Xi.x * (1.0 - Xi.x)) * invQ;
			vec3 L = N * NdotL + (tangent * cos(phi) + bitangent * sin(phi)) * sinTheta;

			// The source mip that matches the sample's solid angle; weighted by NdotL (split sum).
			float d = alpha2 * invQ;
			float lod = max(log2(d) + ggx_info.lod_bias, 0.0);
			prefilteredColor += textureLod(source, L, lod).rgb * NdotL;
			totalWeight += NdotL;
		}
	}

	return prefilteredColor / totalWeight;
}

void main() {
	vec3 N = normalize(faceDirection());

	// At very low roughness the environment is sampled directly.
	if (ggx_info.roughness < 0.001) {
		frag_color = vec4(textureLod(source, N, 0.0).rgb, 1.0);
	} else {
		frag_color = vec4(convolve(N, ggx_info.roughness), 1.0);
	}
}
