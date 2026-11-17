#version 460 core

// The reference's VSM blur (ShaderLib vsm.glsl): one pass of the separable blur of a VSMShadowMap. The vertical
// pass reads the depth in r (the light's depth map, nearest) and writes the mean and standard deviation; the
// horizontal pass reads those (LinearFilter) and writes the map the receivers sample. VSM_SAMPLES and
// HORIZONTAL_PASS are uniforms here (a program per value is not needed: the loop is bounded by a uniform).
uniform VsmInfo {
	vec2 resolution;
	float radius;

	// VSM_SAMPLES (shadow.blurSamples).
	float samples;

	// HORIZONTAL_PASS, 1 or 0.
	float horizontal;
} vsm_info;

uniform sampler2D shadow_pass;

out vec4 frag_color;

void main() {
	float samples = vsm_info.samples;
	float mean = 0.0;
	float squared_mean = 0.0;
	float uvStride = samples <= 1.0 ? 0.0 : 2.0 / (samples - 1.0);
	float uvStart = samples <= 1.0 ? 0.0 : -1.0;

	for (float i = 0.0; i < samples; i++) {
		float uvOffset = uvStart + i * uvStride;

		if (vsm_info.horizontal > 0.5) {
			vec2 distribution = texture(shadow_pass, (gl_FragCoord.xy + vec2(uvOffset, 0.0) * vsm_info.radius)
				/ vsm_info.resolution).rg;
			mean += distribution.x;
			squared_mean += distribution.y * distribution.y + distribution.x * distribution.x;
		} else {
			float depth = texture(shadow_pass, (gl_FragCoord.xy + vec2(0.0, uvOffset) * vsm_info.radius)
				/ vsm_info.resolution).r;
			mean += depth;
			squared_mean += depth * depth;
		}
	}

	mean = mean / samples;
	squared_mean = squared_mean / samples;

	float std_dev = sqrt(max(0.0, squared_mean - mean * mean));
	frag_color = vec4(mean, std_dev, 0.0, 1.0);
}
