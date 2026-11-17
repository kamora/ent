#version 460 core

// FXAAMaterial's fragment stage (the reference's FXAAShader): FXAA algorithm from NVIDIA, C# implementation by Jasper
// Flick, GLSL port by Dave Hoskins. Every coordinate is WebGL's vUv (t up); only Sample flips t for a render target's
// texture (effectUv), so each offset reaches the texel it reaches in the reference.
#include "shaders/effect.glsl"

uniform FragInfo {
	vec2 resolution;

	// 1 when t_diffuse is a render target's texture.
	float flip;
} frag_info;

uniform sampler2D t_diffuse;

#define EDGE_STEP_COUNT 6
#define EDGE_GUESS 8.0
#define EDGE_STEPS 1.0, 1.5, 2.0, 2.0, 2.0, 4.0
const float edgeSteps[EDGE_STEP_COUNT] = float[EDGE_STEP_COUNT](EDGE_STEPS);

const float _ContrastThreshold = 0.0312;
const float _RelativeThreshold = 0.063;
const float _SubpixelBlending = 1.0;

vec4 Sample(vec2 uv) {
	return texture(t_diffuse, effectUv(uv, frag_info.flip));
}

float SampleLuminance(vec2 uv) {
	return dot(Sample(uv).rgb, vec3(0.3, 0.59, 0.11));
}

float SampleLuminance(vec2 texSize, vec2 uv, float uOffset, float vOffset) {
	uv += texSize * vec2(uOffset, vOffset);
	return SampleLuminance(uv);
}

struct LuminanceData {
	float m, n, e, s, w;
	float ne, nw, se, sw;
	float highest, lowest, contrast;
};

LuminanceData SampleLuminanceNeighborhood(vec2 texSize, vec2 uv) {
	LuminanceData l;
	l.m = SampleLuminance(uv);
	l.n = SampleLuminance(texSize, uv, 0.0, 1.0);
	l.e = SampleLuminance(texSize, uv, 1.0, 0.0);
	l.s = SampleLuminance(texSize, uv, 0.0, -1.0);
	l.w = SampleLuminance(texSize, uv, -1.0, 0.0);

	l.ne = SampleLuminance(texSize, uv, 1.0, 1.0);
	l.nw = SampleLuminance(texSize, uv, -1.0, 1.0);
	l.se = SampleLuminance(texSize, uv, 1.0, -1.0);
	l.sw = SampleLuminance(texSize, uv, -1.0, -1.0);

	l.highest = max(max(max(max(l.n, l.e), l.s), l.w), l.m);
	l.lowest = min(min(min(min(l.n, l.e), l.s), l.w), l.m);
	l.contrast = l.highest - l.lowest;
	return l;
}

bool ShouldSkipPixel(LuminanceData l) {
	float threshold = max(_ContrastThreshold, _RelativeThreshold * l.highest);
	return l.contrast < threshold;
}

float DeterminePixelBlendFactor(LuminanceData l) {
	float f = 2.0 * (l.n + l.e + l.s + l.w);
	f += l.ne + l.nw + l.se + l.sw;
	f *= 1.0 / 12.0;
	f = abs(f - l.m);
	f = clamp(f / l.contrast, 0.0, 1.0);

	float blendFactor = smoothstep(0.0, 1.0, f);
	return blendFactor * blendFactor * _SubpixelBlending;
}

struct EdgeData {
	bool isHorizontal;
	float pixelStep;
	float oppositeLuminance, gradient;
};

EdgeData DetermineEdge(vec2 texSize, LuminanceData l) {
	EdgeData e;
	float horizontal =
		abs(l.n + l.s - 2.0 * l.m) * 2.0 +
		abs(l.ne + l.se - 2.0 * l.e) +
		abs(l.nw + l.sw - 2.0 * l.w);
	float vertical =
		abs(l.e + l.w - 2.0 * l.m) * 2.0 +
		abs(l.ne + l.nw - 2.0 * l.n) +
		abs(l.se + l.sw - 2.0 * l.s);
	e.isHorizontal = horizontal >= vertical;

	float pLuminance = e.isHorizontal ? l.n : l.e;
	float nLuminance = e.isHorizontal ? l.s : l.w;
	float pGradient = abs(pLuminance - l.m);
	float nGradient = abs(nLuminance - l.m);

	e.pixelStep = e.isHorizontal ? texSize.y : texSize.x;

	if (pGradient < nGradient) {
		e.pixelStep = -e.pixelStep;
		e.oppositeLuminance = nLuminance;
		e.gradient = nGradient;
	} else {
		e.oppositeLuminance = pLuminance;
		e.gradient = pGradient;
	}

	return e;
}

float DetermineEdgeBlendFactor(vec2 texSize, LuminanceData l, EdgeData e, vec2 uv) {
	vec2 uvEdge = uv;
	vec2 edgeStep;
	if (e.isHorizontal) {
		uvEdge.y += e.pixelStep * 0.5;
		edgeStep = vec2(texSize.x, 0.0);
	} else {
		uvEdge.x += e.pixelStep * 0.5;
		edgeStep = vec2(0.0, texSize.y);
	}

	float edgeLuminance = (l.m + e.oppositeLuminance) * 0.5;
	float gradientThreshold = e.gradient * 0.25;

	vec2 puv = uvEdge + edgeStep * edgeSteps[0];
	float pLuminanceDelta = SampleLuminance(puv) - edgeLuminance;
	bool pAtEnd = abs(pLuminanceDelta) >= gradientThreshold;

	for (int i = 1; i < EDGE_STEP_COUNT && !pAtEnd; i++) {
		puv += edgeStep * edgeSteps[i];
		pLuminanceDelta = SampleLuminance(puv) - edgeLuminance;
		pAtEnd = abs(pLuminanceDelta) >= gradientThreshold;
	}

	if (!pAtEnd) {
		puv += edgeStep * EDGE_GUESS;
	}

	vec2 nuv = uvEdge - edgeStep * edgeSteps[0];
	float nLuminanceDelta = SampleLuminance(nuv) - edgeLuminance;
	bool nAtEnd = abs(nLuminanceDelta) >= gradientThreshold;

	for (int i = 1; i < EDGE_STEP_COUNT && !nAtEnd; i++) {
		nuv -= edgeStep * edgeSteps[i];
		nLuminanceDelta = SampleLuminance(nuv) - edgeLuminance;
		nAtEnd = abs(nLuminanceDelta) >= gradientThreshold;
	}

	if (!nAtEnd) {
		nuv -= edgeStep * EDGE_GUESS;
	}

	float pDistance, nDistance;
	if (e.isHorizontal) {
		pDistance = puv.x - uv.x;
		nDistance = uv.x - nuv.x;
	} else {
		pDistance = puv.y - uv.y;
		nDistance = uv.y - nuv.y;
	}

	float shortestDistance;
	bool deltaSign;
	if (pDistance <= nDistance) {
		shortestDistance = pDistance;
		deltaSign = pLuminanceDelta >= 0.0;
	} else {
		shortestDistance = nDistance;
		deltaSign = nLuminanceDelta >= 0.0;
	}

	if (deltaSign == (l.m - edgeLuminance >= 0.0)) {
		return 0.0;
	}

	return 0.5 - shortestDistance / (pDistance + nDistance);
}

vec4 ApplyFXAA(vec2 texSize, vec2 uv) {
	LuminanceData luminance = SampleLuminanceNeighborhood(texSize, uv);
	if (ShouldSkipPixel(luminance)) {
		return Sample(uv);
	}

	float pixelBlend = DeterminePixelBlendFactor(luminance);
	EdgeData edge = DetermineEdge(texSize, luminance);
	float edgeBlend = DetermineEdgeBlendFactor(texSize, luminance, edge, uv);
	float finalBlend = max(pixelBlend, edgeBlend);

	if (edge.isHorizontal) {
		uv.y += edge.pixelStep * finalBlend;
	} else {
		uv.x += edge.pixelStep * finalBlend;
	}

	return Sample(uv);
}

void main() {
	frag_color = ApplyFXAA(frag_info.resolution.xy, v_uv);
}
