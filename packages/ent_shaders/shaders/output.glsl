// The end of the reference's material fragment shaders, from opaque_fragment to premultiplied_alpha_fragment (tone
// mapping, output color space, fog, premultiplied alpha), and the polygon offset (offset.glsl). Every switch is
// a uniform (exception E-SHADERS).
#include "shaders/offset.glsl"

uniform OutputInfo {
	vec3 fog_color;

	// 0: no fog, 1: Fog (fog_near, fog_far), 2: FogExp2 (fog_density).
	float fog_mode;
	float fog_near;
	float fog_far;
	float fog_density;

	// OPAQUE, PREMULTIPLIED_ALPHA.
	float opaque;
	float premultiplied_alpha;

	// The renderer's toneMapping constant (0: none) and toneMappingExposure.
	float tone_mapping;
	float tone_mapping_exposure;

	// 1 for an sRGB output color space, 0 for linear.
	float output_srgb;

	// How rows run, 1 up (first row at the bottom, as in WebGL) or -1 down: in this draw's target (window y, dFdy,
	// gl_FragCoord) and in 2D render targets the draw samples (shadow maps, the transmission target). Flutter GPU
	// draws every target with its first row at the top; OpenGL ES draws 2D targets and the frame as WebGL does.
	float rows;
	float target_rows;
} output_info;

vec4 sRGBTransferOETF(vec4 value) {
	return vec4(
		mix(
			pow(value.rgb, vec3(0.41666)) * 1.055 - vec3(0.055),
			value.rgb * 12.92,
			vec3(lessThanEqual(value.rgb, vec3(0.0031308)))
		),
		value.a
	);
}

// tonemapping_pars_fragment.
vec3 LinearToneMapping(vec3 color) {
	return saturate(output_info.tone_mapping_exposure * color);
}

vec3 ReinhardToneMapping(vec3 color) {
	color *= output_info.tone_mapping_exposure;
	return saturate(color / (vec3(1.0) + color));
}

vec3 CineonToneMapping(vec3 color) {
	color *= output_info.tone_mapping_exposure;
	color = max(vec3(0.0), color - 0.004);
	return pow((color * (6.2 * color + 0.5)) / (color * (6.2 * color + 1.7) + 0.06), vec3(2.2));
}

vec3 RRTAndODTFit(vec3 v) {
	vec3 a = v * (v + 0.0245786) - 0.000090537;
	vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
	return a / b;
}

vec3 ACESFilmicToneMapping(vec3 color) {
	const mat3 ACESInputMat = mat3(
		vec3(0.59719, 0.07600, 0.02840),
		vec3(0.35458, 0.90834, 0.13383),
		vec3(0.04823, 0.01566, 0.83777)
	);
	const mat3 ACESOutputMat = mat3(
		vec3(1.60475, -0.10208, -0.00327),
		vec3(-0.53108, 1.10813, -0.07276),
		vec3(-0.07367, -0.00605, 1.07602)
	);
	color *= output_info.tone_mapping_exposure / 0.6;
	color = ACESInputMat * color;
	color = RRTAndODTFit(color);
	color = ACESOutputMat * color;
	return saturate(color);
}

const mat3 LINEAR_REC2020_TO_LINEAR_SRGB = mat3(
	vec3(1.6605, -0.1246, -0.0182),
	vec3(-0.5876, 1.1329, -0.1006),
	vec3(-0.0728, -0.0083, 1.1187)
);

const mat3 LINEAR_SRGB_TO_LINEAR_REC2020 = mat3(
	vec3(0.6274, 0.0691, 0.0164),
	vec3(0.3293, 0.9195, 0.0880),
	vec3(0.0433, 0.0113, 0.8956)
);

vec3 agxDefaultContrastApprox(vec3 x) {
	vec3 x2 = x * x;
	vec3 x4 = x2 * x2;
	return +15.5 * x4 * x2 - 40.14 * x4 * x + 31.96 * x4 - 6.868 * x2 * x + 0.4298 * x2 + 0.1191 * x - 0.00232;
}

vec3 AgXToneMapping(vec3 color) {
	const mat3 AgXInsetMatrix = mat3(
		vec3(0.856627153315983, 0.137318972929847, 0.11189821299995),
		vec3(0.0951212405381588, 0.761241990602591, 0.0767994186031903),
		vec3(0.0482516061458583, 0.101439036467562, 0.811302368396859)
	);
	const mat3 AgXOutsetMatrix = mat3(
		vec3(1.1271005818144368, -0.1413297634984383, -0.14132976349843826),
		vec3(-0.11060664309660323, 1.157823702216272, -0.11060664309660294),
		vec3(-0.016493938717834573, -0.016493938717834257, 1.2519364065950405)
	);
	const float AgxMinEv = -12.47393;
	const float AgxMaxEv = 4.026069;
	color *= output_info.tone_mapping_exposure;
	color = LINEAR_SRGB_TO_LINEAR_REC2020 * color;
	color = AgXInsetMatrix * color;
	color = max(color, 1e-10);
	color = log2(color);
	color = (color - AgxMinEv) / (AgxMaxEv - AgxMinEv);
	color = clamp(color, 0.0, 1.0);
	color = agxDefaultContrastApprox(color);
	color = AgXOutsetMatrix * color;
	color = pow(max(vec3(0.0), color), vec3(2.2));
	color = LINEAR_REC2020_TO_LINEAR_SRGB * color;
	color = clamp(color, 0.0, 1.0);
	return color;
}

vec3 NeutralToneMapping(vec3 color) {
	const float StartCompression = 0.8 - 0.04;
	const float Desaturation = 0.15;
	color *= output_info.tone_mapping_exposure;
	float x = min(color.r, min(color.g, color.b));
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;
	float peak = max(color.r, max(color.g, color.b));

	if (peak < StartCompression) {
		return color;
	}

	float d = 1. - StartCompression;
	float newPeak = 1. - d * d / (peak + d - StartCompression);
	color *= newPeak / peak;
	float g = 1. - 1. / (Desaturation * (peak - newPeak) + 1.);
	return mix(color, vec3(newPeak), g);
}

// The reference's toneMapping(): the constants of its tone mapping types; CustomToneMapping (5) is the identity
// (its chunk returns the color), and the renderer maps an unknown constant to LinearToneMapping (1).
vec3 toneMapping(vec3 color) {
	int mode = int(output_info.tone_mapping + 0.5);

	if (mode == 2) {
		return ReinhardToneMapping(color);
	} else if (mode == 3) {
		return CineonToneMapping(color);
	} else if (mode == 4) {
		return ACESFilmicToneMapping(color);
	} else if (mode == 5) {
		return color;
	} else if (mode == 6) {
		return AgXToneMapping(color);
	} else if (mode == 7) {
		return NeutralToneMapping(color);
	}

	return LinearToneMapping(color);
}

// tonemapping_fragment, colorspace_fragment, fog_fragment and premultiplied_alpha_fragment applied to [color];
// [depth] is vFogDepth (-mvPosition.z).
vec4 finishColor(vec4 color, float depth) {
	if (output_info.tone_mapping > 0.5) {
		color.rgb = toneMapping(color.rgb);
	}

	if (output_info.output_srgb > 0.5) {
		color = sRGBTransferOETF(color);
	}

	if (output_info.fog_mode > 0.5) {
		color.rgb = mix(
			color.rgb,
			output_info.fog_color,
			output_info.fog_mode > 1.5
				? 1.0 - exp(-output_info.fog_density * output_info.fog_density * depth * depth)
				: smoothstep(output_info.fog_near, output_info.fog_far, depth)
		);
	}

	if (output_info.premultiplied_alpha > 0.5) {
		color.rgb *= color.a;
	}

	return color;
}

// opaque_fragment, then finishColor.
vec4 outputColor(vec3 outgoing, float alpha, float depth) {
	return finishColor(vec4(outgoing, output_info.opaque > 0.5 ? 1.0 : alpha), depth);
}
