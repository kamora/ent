// MeshStandardMaterial's and MeshPhysicalMaterial's fragment stage (meshphysical.glsl, STANDARD, and PHYSICAL for
// the physical material): roughness and metalness (with their maps), the GGX BRDF with the DFG term and
// multiple-scattering compensation (lights_physical_pars_fragment), image-based lighting from a PMREM
// (envmaps.glsl), and the physical layers: ior and specular, clearcoat, iridescence, sheen, anisotropy, diffuse
// roughness (EON), retroreflection and transmission. Compiled only as variants (lib/src/gpu/variants.dart): a
// variant's flags define its maps (PHYSICAL_MAPS), layers (LAYER_*, with PHYSICAL), transmission (TRANSMISSION)
// and dispersion (DISPERSION). A layer a variant leaves out is off, and its samplers and blocks are not declared.
// MeshStandardMaterial is a physical material with ior 1.5 and white specular of intensity 1, as the reference's
// values without PHYSICAL are.
//
// The extra maps of the physical material get their uv here (UvInfo), from the raw uv and uv1 of the vertex
// stage: one varying per map would exceed the varying limit.
#include "shaders/slots.glsl"
#include "shaders/output.glsl"
#include "shaders/common.glsl"
#include "shaders/mesh_in.glsl"
#include "shaders/maps.glsl"
#include "shaders/normals.glsl"
#include "shaders/envmaps.glsl"

uniform FragInfo {
	vec3 diffuse;
	float opacity;

	// emissive × emissiveIntensity.
	vec3 emissive;
	float roughness;
	float metalness;

	// IOR and USE_SPECULAR (MeshStandardMaterial: 1.5, 1 and white).
	float ior;
	float specular_intensity;
	vec3 specular_color;

	float clearcoat;
	float clearcoat_roughness;
	vec2 clearcoat_normal_scale;
	float iridescence;
	float iridescence_ior;
	float iridescence_thickness_minimum;
	float iridescence_thickness_maximum;

	// sheenColor × sheen.
	vec3 sheen_color;
	float sheen_roughness;

	// anisotropy × (cos, sin) of anisotropyRotation.
	vec2 anisotropy_vector;
	float diffuse_roughness;
	float retroreflectivity;
	float transmission;
	float thickness;
	float attenuation_distance;
	vec3 attenuation_color;
	float dispersion;

	// The transmission render target's size (transmissionSamplerSize).
	vec2 transmission_size;
} frag_info;

// A variant's layers are its flags (LAYER_*, lib/src/gpu/variants.dart), fixed when it is built.
#ifdef LAYER_CLEARCOAT
#define USE_CLEARCOAT true
#else
#define USE_CLEARCOAT false
#endif

#ifdef LAYER_IRIDESCENCE
#define USE_IRIDESCENCE true
#else
#define USE_IRIDESCENCE false
#endif

#ifdef LAYER_SHEEN
#define USE_SHEEN true
#else
#define USE_SHEEN false
#endif

#ifdef LAYER_ANISOTROPY
#define USE_ANISOTROPY true
#else
#define USE_ANISOTROPY false
#endif

#ifdef LAYER_DIFFUSE_ROUGHNESS
#define USE_DIFFUSE_ROUGHNESS true
#else
#define USE_DIFFUSE_ROUGHNESS false
#endif

#ifdef TRANSMISSION
#define USE_TRANSMISSION true
#else
#define USE_TRANSMISSION false
#endif

#ifdef DISPERSION
#define USE_DISPERSION true
#else
#define USE_DISPERSION false
#endif

// The physical maps' uv transforms (mat3 as the upper-left of a mat4) and channels (0: uv, 1: uv1), by index:
// 0 roughness, 1 metalness, 2 clearcoat, 3 clearcoatRoughness, 4 clearcoatNormal, 5 sheenColor, 6 sheenRoughness,
// 7 iridescence, 8 iridescenceThickness, 9 anisotropy, 10 specularIntensity, 11 specularColor,
// 12 diffuseRoughness, 13 transmission, 14 thickness.
#ifdef SLOT_MAPS
uniform UvInfo {
	mat4 transform[15];
	vec4 channel[4];
} uv_info;
#endif

#ifdef TRANSMISSION

// The model and projection matrices transmission projects the refracted ray with.
uniform TransmissionInfo {
	mat4 model_matrix;
	mat4 projection_matrix;
} transmission_info;
#endif

uniform sampler2D roughness_map;
uniform sampler2D metalness_map;

uniform sampler2D dfg_lut;

#ifdef PHYSICAL
uniform sampler2D clearcoat_map;
uniform sampler2D clearcoat_roughness_map;
uniform sampler2D clearcoat_normal_map;
uniform sampler2D sheen_color_map;
uniform sampler2D sheen_roughness_map;
uniform sampler2D iridescence_map;
uniform sampler2D iridescence_thickness_map;
uniform sampler2D anisotropy_map;
uniform sampler2D specular_intensity_map;
uniform sampler2D specular_color_map;
uniform sampler2D diffuse_roughness_map;
#endif

#ifdef TRANSMISSION
uniform sampler2D transmission_map;
uniform sampler2D thickness_map;
uniform sampler2D transmission_sampler_map;
#endif

// Whether the physical map [i] (the indices of UvInfo) is in use: bit i of the variant's PHYSICAL_MAPS.
bool useMap(int i) {
	return (PHYSICAL_MAPS & (1 << i)) != 0;
}

#ifdef SLOT_MAPS
vec2 mapUv(int i) {
	vec2 uv = uv_info.channel[i / 4][i % 4] > 0.5 ? v_uv.zw : v_uv.xy;
	return (mat3(uv_info.transform[i]) * vec3(uv, 1.0)).xy;
}
#else

// A stage without maps reads none; the code of the layers it lacks still names mapUv.
vec2 mapUv(int i) {
	return v_uv.xy;
}
#endif

#ifdef SLOT_MAPS

// The slot and uv of the map read [i] of slot_reads (shaders/slots.glsl): the bump map's second and third reads
// are one pixel to the right and up, as dHdxy_fwd reads them.
float slotOf(int i) {
	float[SLOT_READS] slots = float[SLOT_READS](
		slot_info.map,
		slot_info.alpha_map,
		slot_info.specular_map,
		slot_info.emissive_map,
		slot_info.ao_map,
		slot_info.light_map,
		slot_info.bump_map,
		slot_info.bump_map,
		slot_info.bump_map,
		slot_info.normal_map,
		slot_info.roughness_map,
		slot_info.metalness_map
#ifdef PHYSICAL
		,
		slot_info.clearcoat_map,
		slot_info.clearcoat_roughness_map,
		slot_info.clearcoat_normal_map,
		slot_info.sheen_color_map,
		slot_info.sheen_roughness_map,
		slot_info.iridescence_map,
		slot_info.iridescence_thickness_map,
		slot_info.anisotropy_map,
		slot_info.specular_intensity_map,
		slot_info.specular_color_map,
		slot_info.diffuse_roughness_map
#endif
#ifdef TRANSMISSION
		,
		slot_info.transmission_map,
		slot_info.thickness_map
#endif
	);
	return slots[i];
}

vec2 slotUv(int i, vec2 dx, vec2 dy) {
	if (i >= READ_ROUGHNESS_MAP) {
		return mapUv(i - READ_ROUGHNESS_MAP);
	}

	vec2[READ_ROUGHNESS_MAP] uvs = vec2[READ_ROUGHNESS_MAP](
		v_map_uv,
		v_alpha_map_uv,
		v_specular_map_uv,
		v_emissive_map_uv,
		v_ao_map_uv,
		v_light_map_uv,
		v_bump_map_uv,
		v_bump_map_uv + dx,
		v_bump_map_uv + dy,
		v_normal_map_uv
	);
	return uvs[i];
}

// Reads each map of the draw once, before anything else of main: the loop's body is the stage's only 15-way
// slot branch (shaders/slots.glsl). Each read is stored at a constant index: storing it at slot_reads[i] drew
// parts of standard_maps wrong on the iPhone 11, differently every frame (the M1 drew it right), and explicit
// gradients did not help.
void readSlots() {
	vec2 dx = dFdx(v_bump_map_uv);
	vec2 dy = dFdyGL(v_bump_map_uv);

	for (int i = 0; i < SLOT_READS; i++) {
		vec4 read = slotTexture(slotOf(i), slotUv(i, dx, dy));

		if (i == 0) {
			slot_reads[0] = read;
		}

		if (i == 1) {
			slot_reads[1] = read;
		}

		if (i == 2) {
			slot_reads[2] = read;
		}

		if (i == 3) {
			slot_reads[3] = read;
		}

		if (i == 4) {
			slot_reads[4] = read;
		}

		if (i == 5) {
			slot_reads[5] = read;
		}

		if (i == 6) {
			slot_reads[6] = read;
		}

		if (i == 7) {
			slot_reads[7] = read;
		}

		if (i == 8) {
			slot_reads[8] = read;
		}

		if (i == 9) {
			slot_reads[9] = read;
		}

		if (i == 10) {
			slot_reads[10] = read;
		}

		if (i == 11) {
			slot_reads[11] = read;
		}

#if 12 < SLOT_READS
		if (i == 12) {
			slot_reads[12] = read;
		}
#endif

#if 13 < SLOT_READS
		if (i == 13) {
			slot_reads[13] = read;
		}
#endif

#if 14 < SLOT_READS
		if (i == 14) {
			slot_reads[14] = read;
		}
#endif

#if 15 < SLOT_READS
		if (i == 15) {
			slot_reads[15] = read;
		}
#endif

#if 16 < SLOT_READS
		if (i == 16) {
			slot_reads[16] = read;
		}
#endif

#if 17 < SLOT_READS
		if (i == 17) {
			slot_reads[17] = read;
		}
#endif

#if 18 < SLOT_READS
		if (i == 18) {
			slot_reads[18] = read;
		}
#endif

#if 19 < SLOT_READS
		if (i == 19) {
			slot_reads[19] = read;
		}
#endif

#if 20 < SLOT_READS
		if (i == 20) {
			slot_reads[20] = read;
		}
#endif

#if 21 < SLOT_READS
		if (i == 21) {
			slot_reads[21] = read;
		}
#endif

#if 22 < SLOT_READS
		if (i == 22) {
			slot_reads[22] = read;
		}
#endif

#if 23 < SLOT_READS
		if (i == 23) {
			slot_reads[23] = read;
		}
#endif

#if 24 < SLOT_READS
		if (i == 24) {
			slot_reads[24] = read;
		}
#endif
	}
}
#endif

struct PhysicalMaterial {
	vec3 diffuseColor;
	vec3 diffuseContribution;
	vec3 specularColor;
	vec3 specularColorBlended;
	float roughness;
	float metalness;
	float specularF90;
	float dispersion;
	vec2 dfg;
	vec3 multiScatteringCompensation;
	float diffuseRoughness;
	float retroreflectivity;
	float clearcoat;
	float clearcoatRoughness;
	vec3 clearcoatF0;
	float clearcoatF90;

	// geometryClearcoatNormal, which the reference passes to RE_Direct on its own.
	vec3 clearcoatNormal;
	float iridescence;
	float iridescenceIOR;
	float iridescenceThickness;
	vec3 iridescenceFresnel;
	vec3 iridescenceF0Dielectric;
	vec3 iridescenceF0Metallic;
	vec3 sheenColor;
	float sheenRoughness;
	float ior;
	float transmission;
	float transmissionAlpha;
	float thickness;
	float attenuationDistance;
	vec3 attenuationColor;
	float anisotropy;
	float alphaT;
	vec3 anisotropyT;
	vec3 anisotropyB;
};

vec3 clearcoatSpecularDirect = vec3(0.0);
vec3 clearcoatSpecularIndirect = vec3(0.0);
vec3 sheenSpecularDirect = vec3(0.0);
vec3 sheenSpecularIndirect = vec3(0.0);

// iridescence_fragment: thin-film interference (Belcour and Barla 2017).
const mat3 XYZ_TO_REC709 = mat3(
	3.2404542, -0.9692660, 0.0556434,
	-1.5371385, 1.8760108, -0.2040259,
	-0.4985314, 0.0415560, 1.0572252
);

vec3 Fresnel0ToIor(vec3 fresnel0) {
	vec3 sqrtF0 = sqrt(fresnel0);
	return (vec3(1.0) + sqrtF0) / (vec3(1.0) - sqrtF0);
}

vec3 IorToFresnel0(vec3 transmittedIor, float incidentIor) {
	return pow2((transmittedIor - vec3(incidentIor)) / (transmittedIor + vec3(incidentIor)));
}

float IorToFresnel0(float transmittedIor, float incidentIor) {
	return pow2((transmittedIor - incidentIor) / (transmittedIor + incidentIor));
}

vec3 evalSensitivity(float OPD, vec3 shift) {
	float phase = 2.0 * PI * OPD * 1.0e-9;
	vec3 val = vec3(5.4856e-13, 4.4201e-13, 5.2481e-13);
	vec3 pos = vec3(1.6810e+06, 1.7953e+06, 2.2084e+06);
	vec3 var = vec3(4.3278e+09, 9.3046e+09, 6.6121e+09);
	vec3 xyz = val * sqrt(2.0 * PI * var) * cos(pos * phase + shift) * exp(-pow2(phase) * var);
	xyz.x += 9.7470e-14 * sqrt(2.0 * PI * 4.5282e+09) * cos(2.2399e+06 * phase + shift[0])
		* exp(-4.5282e+09 * pow2(phase));
	xyz /= 1.0685e-7;
	return XYZ_TO_REC709 * xyz;
}

vec3 evalIridescence(float outsideIOR, float eta2, float cosTheta1, float thinFilmThickness, vec3 baseF0) {
	vec3 I;

	// Force iridescenceIOR -> outsideIOR when thinFilmThickness -> 0.0.
	float iridescenceIOR = mix(outsideIOR, eta2, smoothstep(0.0, 0.03, thinFilmThickness));

	// Snell's law gives cosTheta on the base layer; total internal reflection returns 1.
	float sinTheta2Sq = pow2(outsideIOR / iridescenceIOR) * (1.0 - pow2(cosTheta1));
	float cosTheta2Sq = 1.0 - sinTheta2Sq;

	if (cosTheta2Sq < 0.0) {
		return vec3(1.0);
	}

	float cosTheta2 = sqrt(cosTheta2Sq);

	// First interface.
	float R0 = IorToFresnel0(iridescenceIOR, outsideIOR);
	float R12 = F_Schlick(R0, 1.0, cosTheta1);
	float T121 = 1.0 - R12;
	float phi12 = 0.0;

	if (iridescenceIOR < outsideIOR) {
		phi12 = PI;
	}

	float phi21 = PI - phi12;

	// Second interface, guarded against baseF0 = 1.
	vec3 baseIOR = Fresnel0ToIor(clamp(baseF0, 0.0, 0.9999));
	vec3 R1 = IorToFresnel0(baseIOR, iridescenceIOR);
	vec3 R23 = F_Schlick(R1, 1.0, cosTheta2);
	vec3 phi23 = vec3(0.0);

	if (baseIOR[0] < iridescenceIOR) {
		phi23[0] = PI;
	}

	if (baseIOR[1] < iridescenceIOR) {
		phi23[1] = PI;
	}

	if (baseIOR[2] < iridescenceIOR) {
		phi23[2] = PI;
	}

	// Phase shift, compound terms, the DC term and the pairs of diracs for m > 0.
	float OPD = 2.0 * iridescenceIOR * thinFilmThickness * cosTheta2;
	vec3 phi = vec3(phi21) + phi23;
	vec3 R123 = clamp(R12 * R23, 1e-5, 0.9999);
	vec3 r123 = sqrt(R123);
	vec3 Rs = pow2(T121) * R23 / (vec3(1.0) - R123);
	vec3 C0 = R12 + Rs;
	I = C0;

	vec3 Cm = Rs - T121;

	for (int m = 1; m <= 2; ++m) {
		Cm *= r123;
		vec3 Sm = 2.0 * evalSensitivity(float(m) * OPD, float(m) * phi);
		I += Cm * Sm;
	}

	// Out-of-gamut colors are clamped to 0.
	return max(I, vec3(0.0));
}

vec3 Schlick_to_F0(vec3 f, float f90, float dotVH) {
	float x = clamp(1.0 - dotVH, 0.0, 1.0);
	float x2 = x * x;
	float x5 = clamp(x * x2 * x2, 0.0, 0.9999);
	return (f - vec3(f90) * x5) / (1.0 - x5);
}

// EON: a practical energy-preserving rough diffuse BRDF (Portsmouth et al. 2025).
const float EON_EPSILON = 1e-7;

float FON_DirectionalAlbedo(float mu, float roughness, float A) {
	float muComp = 1.0 - mu;
	float gOverPi = muComp * (0.0571085289 + muComp * (0.491881867 + muComp * (-0.332181442 + muComp * 0.0714429953)));
	return A * (1.0 + roughness * gOverPi);
}

vec3 BRDF_EON(vec3 lightDir, vec3 viewDir, vec3 normal, vec3 diffuseColor, float roughness) {
	vec3 rho = saturate(diffuseColor);

	if (roughness <= EON_EPSILON) {
		return BRDF_Lambert(rho);
	}

	float dotNL = saturate(dot(normal, lightDir));
	float dotNV = saturate(dot(normal, viewDir));
	float s = dot(lightDir, viewDir) - dotNL * dotNV;
	float sOverT = (s > 0.0) ? s / max(max(dotNL, dotNV), EON_EPSILON) : s;
	float A = 1.0 / (1.0 + (0.5 - 2.0 / (3.0 * PI)) * roughness);
	vec3 singleScatter = rho * RECIPROCAL_PI * A * (1.0 + roughness * sOverT);
	float averageAlbedo = A * (1.0 + (2.0 / 3.0 - 28.0 / (15.0 * PI)) * roughness);
	float albedoV = FON_DirectionalAlbedo(dotNV, roughness, A);
	float albedoL = FON_DirectionalAlbedo(dotNL, roughness, A);
	vec3 rhoMultiScatter = rho * rho * averageAlbedo / max(vec3(EON_EPSILON), vec3(1.0) - rho * (1.0 - averageAlbedo));
	vec3 multiScatter = rhoMultiScatter * RECIPROCAL_PI
		* max(EON_EPSILON, 1.0 - albedoV)
		* max(EON_EPSILON, 1.0 - albedoL)
		/ max(EON_EPSILON, 1.0 - averageAlbedo);
	return singleScatter + multiScatter;
}

vec3 EON_DirectionalAlbedo(vec3 diffuseColor, float roughness, float dotNV) {
	vec3 rho = saturate(diffuseColor);

	if (roughness <= EON_EPSILON) {
		return rho;
	}

	float A = 1.0 / (1.0 + (0.5 - 2.0 / (3.0 * PI)) * roughness);
	float directionalAlbedo = FON_DirectionalAlbedo(dotNV, roughness, A);
	float averageAlbedo = A * (1.0 + (2.0 / 3.0 - 28.0 / (15.0 * PI)) * roughness);
	vec3 rhoMultiScatter = rho * rho * averageAlbedo / max(vec3(EON_EPSILON), vec3(1.0) - rho * (1.0 - averageAlbedo));
	return rho * directionalAlbedo + rhoMultiScatter * (1.0 - directionalAlbedo);
}

// Moving Frostbite to Physically Based Rendering 3.0, page 12, listing 2.
float V_GGX_SmithCorrelated(float alpha, float dotNL, float dotNV) {
	float a2 = pow2(alpha);
	float gv = dotNL * sqrt(a2 + (1.0 - a2) * pow2(dotNV));
	float gl = dotNV * sqrt(a2 + (1.0 - a2) * pow2(dotNL));
	return 0.5 / max(gv + gl, EPSILON);
}

// Microfacet Models for Refraction through Rough Surfaces, equation 33; alpha is roughness squared.
float D_GGX(float alpha, float dotNH) {
	float a2 = pow2(alpha);
	float denom = pow2(dotNH) * (a2 - 1.0) + 1.0;
	return RECIPROCAL_PI * a2 / pow2(denom);
}

// Filament's anisotropic specular BRDF.
float V_GGX_SmithCorrelated_Anisotropic(float alphaT, float alphaB, float dotTV, float dotBV, float dotTL, float dotBL,
		float dotNV, float dotNL) {
	float gv = dotNL * length(vec3(alphaT * dotTV, alphaB * dotBV, dotNV));
	float gl = dotNV * length(vec3(alphaT * dotTL, alphaB * dotBL, dotNL));
	return 0.5 / max(gv + gl, EPSILON);
}

float D_GGX_Anisotropic(float alphaT, float alphaB, float dotNH, float dotTH, float dotBH) {
	float a2 = alphaT * alphaB;
	vec3 v = vec3(alphaB * dotTH, alphaT * dotBH, a2 * dotNH);
	float v2 = dot(v, v);
	float w2 = a2 / v2;
	return RECIPROCAL_PI * a2 * pow2(w2);
}

// GGX distribution, Schlick Fresnel and GGX_SmithCorrelated visibility for the clearcoat layer.
vec3 BRDF_GGX_Clearcoat(vec3 lightDir, vec3 viewDir, vec3 normal, PhysicalMaterial material) {
	vec3 f0 = material.clearcoatF0;
	float f90 = material.clearcoatF90;

	// Punctual lights need a minimum roughness to show a highlight.
	float roughness = max(material.clearcoatRoughness, 0.045);
	float alpha = pow2(roughness);
	vec3 halfDir = normalize(lightDir + viewDir);
	float dotNL = saturate(dot(normal, lightDir));
	float dotNV = saturate(dot(normal, viewDir));
	float dotNH = saturate(dot(normal, halfDir));
	float dotVH = saturate(dot(viewDir, halfDir));
	vec3 F = F_Schlick(f0, f90, dotVH);
	float V = V_GGX_SmithCorrelated(alpha, dotNL, dotNV);
	float D = D_GGX(alpha, dotNH);
	return F * (V * D);
}

vec3 BRDF_GGX(vec3 lightDir, vec3 viewDir, vec3 normal, PhysicalMaterial material) {
	vec3 f0 = material.specularColorBlended;
	float f90 = material.specularF90;
	float roughness = max(material.roughness, 0.045);
	float alpha = pow2(roughness);
	vec3 halfDir = normalize(lightDir + viewDir);
	float dotNL = saturate(dot(normal, lightDir));
	float dotNV = saturate(dot(normal, viewDir));
	float dotNH = saturate(dot(normal, halfDir));
	float dotVH = saturate(dot(viewDir, halfDir));
	vec3 F = F_Schlick(f0, f90, dotVH);

	if (USE_IRIDESCENCE) {
		F = mix(F, material.iridescenceFresnel, material.iridescence);
	}

	float V;
	float D;

	if (USE_ANISOTROPY) {
		float dotTL = dot(material.anisotropyT, lightDir);
		float dotTV = dot(material.anisotropyT, viewDir);
		float dotTH = dot(material.anisotropyT, halfDir);
		float dotBL = dot(material.anisotropyB, lightDir);
		float dotBV = dot(material.anisotropyB, viewDir);
		float dotBH = dot(material.anisotropyB, halfDir);
		float alphaT = max(material.alphaT, alpha);
		V = V_GGX_SmithCorrelated_Anisotropic(alphaT, alpha, dotTV, dotBV, dotTL, dotBL, dotNV, dotNL);
		D = D_GGX_Anisotropic(alphaT, alpha, dotNH, dotTH, dotBH);
	} else {
		V = V_GGX_SmithCorrelated(alpha, dotNL, dotNV);
		D = D_GGX(alpha, dotNH);
	}

	return F * (V * D);
}

// Charlie sheen (Estevez and Kulla 2017) with Neubelt visibility, after Filament.
float D_Charlie(float roughness, float dotNH) {
	float alpha = pow2(roughness);
	float invAlpha = 1.0 / alpha;
	float cos2h = dotNH * dotNH;

	// 2^(-14/2), so sin2h^2 > 0 in fp16.
	float sin2h = max(1.0 - cos2h, 0.0078125);
	return (2.0 + invAlpha) * pow(sin2h, invAlpha * 0.5) / (2.0 * PI);
}

float V_Neubelt(float dotNV, float dotNL) {
	return saturate(1.0 / (4.0 * (dotNL + dotNV - dotNL * dotNV)));
}

vec3 BRDF_Sheen(vec3 lightDir, vec3 viewDir, vec3 normal, vec3 sheenColor, float sheenRoughness) {
	vec3 halfDir = normalize(lightDir + viewDir);
	float dotNL = saturate(dot(normal, lightDir));
	float dotNV = saturate(dot(normal, viewDir));
	float dotNH = saturate(dot(normal, halfDir));
	float D = D_Charlie(sheenRoughness, dotNH);
	float V = V_Neubelt(dotNV, dotNL);
	return sheenColor * (D * V);
}

// A curve fit of the Charlie sheen BRDF integrated over the hemisphere.
float IBLSheenBRDF(vec3 normal, vec3 viewDir, float roughness) {
	float dotNV = saturate(dot(normal, viewDir));
	float r2 = roughness * roughness;
	float rInv = 1.0 / (roughness + 0.1);
	float a = -1.9362 + 1.0678 * roughness + 0.4573 * r2 - 0.8469 * rInv;
	float b = -0.6014 + 0.5538 * roughness - 0.4670 * r2 - 0.1255 * rInv;
	float DG = exp(a * dotNV + b);
	return saturate(DG);
}

vec3 EnvironmentBRDF(vec3 normal, vec3 viewDir, vec3 specularColor, float specularF90, float roughness) {
	float dotNV = saturate(dot(normal, viewDir));
	vec2 fab = texture(dfg_lut, vec2(roughness, dotNV)).rg;
	return specularColor * fab.x + specularF90 * fab.y;
}

// Fdez-Agüera's multiple-scattering microfacet model for image-based lighting; with iridescence, Fr mixes in
// [iridescenceF0] by [iridescence] (computeMultiscatteringIridescence).
void computeMultiscattering(vec2 fab, vec3 specularColor, float specularF90, float iridescence, vec3 iridescenceF0,
		inout vec3 singleScatter, inout vec3 multiScatter) {
	vec3 Fr = USE_IRIDESCENCE ? mix(specularColor, iridescenceF0, iridescence) : specularColor;
	vec3 FssEss = Fr * fab.x + specularF90 * fab.y;
	float Ess = fab.x + fab.y;
	float Ems = 1.0 - Ess;
	vec3 Favg = Fr + (1.0 - Fr) * 0.047619;
	vec3 Fms = FssEss * Favg / (1.0 - Ems * Favg);
	singleScatter += FssEss;
	multiScatter += Fms * Ems;
}

void RE_Direct(IncidentLight directLight, vec3 geometryPosition, vec3 geometryNormal, vec3 geometryViewDir,
		PhysicalMaterial material, inout ReflectedLight reflectedLight) {
	float dotNL = saturate(dot(geometryNormal, directLight.direction));
	vec3 irradiance = dotNL * directLight.color;

	if (USE_CLEARCOAT) {
		float dotNLcc = saturate(dot(material.clearcoatNormal, directLight.direction));
		vec3 ccIrradiance = dotNLcc * directLight.color;
		clearcoatSpecularDirect += ccIrradiance
			* BRDF_GGX_Clearcoat(directLight.direction, geometryViewDir, material.clearcoatNormal, material);
	}

	if (USE_SHEEN) {
		sheenSpecularDirect += irradiance
			* BRDF_Sheen(directLight.direction, geometryViewDir, geometryNormal, material.sheenColor, material.sheenRoughness);

		float sheenAlbedoV = IBLSheenBRDF(geometryNormal, geometryViewDir, material.sheenRoughness);
		float sheenAlbedoL = IBLSheenBRDF(geometryNormal, directLight.direction, material.sheenRoughness);
		float sheenEnergyComp = 1.0 - max3(material.sheenColor) * max(sheenAlbedoV, sheenAlbedoL);
		irradiance *= sheenEnergyComp;
	}

	vec3 specularBRDF = BRDF_GGX(directLight.direction, geometryViewDir, geometryNormal, material);
	vec3 retroViewDir = reflect(-geometryViewDir, geometryNormal);

	// The minimal retroreflective microfacet model (jcgt.org/published/0015/01/04).
	if (frag_info.retroreflectivity > 0.0) {
		vec3 retroSpecularBRDF = BRDF_GGX(directLight.direction, retroViewDir, geometryNormal, material);
		specularBRDF = mix(specularBRDF, retroSpecularBRDF, saturate(material.retroreflectivity));
	}

	reflectedLight.directSpecular += irradiance * specularBRDF * material.multiScatteringCompensation;

	// Light reflected by the specular interface is not available to the diffuse layer (glTF fresnel_mix).
	vec3 halfDir = normalize(directLight.direction + geometryViewDir);
	float dotVH = saturate(dot(geometryViewDir, halfDir));
	vec3 F = F_Schlick(material.specularColor, material.specularF90, dotVH);

	if (frag_info.retroreflectivity > 0.0) {
		vec3 retroHalfDir = normalize(directLight.direction + retroViewDir);
		float dotRetroVH = saturate(dot(retroViewDir, retroHalfDir));
		vec3 retroF = F_Schlick(material.specularColor, material.specularF90, dotRetroVH);
		F = mix(F, retroF, saturate(material.retroreflectivity));
	}

	vec3 diffuseBRDF = USE_DIFFUSE_ROUGHNESS
		? BRDF_EON(directLight.direction, geometryViewDir, geometryNormal, material.diffuseColor, material.diffuseRoughness)
			* (1.0 - material.metalness)
		: BRDF_Lambert(material.diffuseContribution);

	reflectedLight.directDiffuse += irradiance * diffuseBRDF * (1.0 - F);
}

void RE_IndirectDiffuse(vec3 irradiance, vec3 geometryNormal, vec3 geometryViewDir, PhysicalMaterial material,
		inout ReflectedLight reflectedLight) {

	// Energy reflected by the specular lobe is not available to the diffuse layer.
	vec3 singleScattering = vec3(0.0);
	vec3 multiScattering = vec3(0.0);
	computeMultiscattering(material.dfg, material.specularColor, material.specularF90, material.iridescence,
		material.iridescenceF0Dielectric, singleScattering, multiScattering);

	vec3 diffuse;

	if (USE_DIFFUSE_ROUGHNESS) {

		// Irradiance has integrated the cosine term already, so the directional albedo approximates EON under
		// locally uniform incident radiance.
		float dotNV = saturate(dot(geometryNormal, geometryViewDir));
		vec3 diffuseAlbedo = EON_DirectionalAlbedo(material.diffuseColor, material.diffuseRoughness, dotNV)
			* (1.0 - material.metalness);
		diffuse = irradiance * RECIPROCAL_PI * diffuseAlbedo * (1.0 - singleScattering - multiScattering);
	} else {
		diffuse = irradiance * BRDF_Lambert(material.diffuseContribution) * (1.0 - singleScattering - multiScattering);
	}

	if (USE_SHEEN) {
		float sheenAlbedo = IBLSheenBRDF(geometryNormal, geometryViewDir, material.sheenRoughness);
		sheenSpecularIndirect += irradiance * material.sheenColor * sheenAlbedo * RECIPROCAL_PI;
		float sheenEnergyComp = 1.0 - max3(material.sheenColor) * sheenAlbedo;
		diffuse *= sheenEnergyComp;
	}

	reflectedLight.indirectDiffuse += diffuse;
}

void RE_IndirectSpecular(vec3 radiance, vec3 irradiance, vec3 clearcoatRadiance, vec3 geometryNormal,
		vec3 geometryViewDir, PhysicalMaterial material, inout ReflectedLight reflectedLight) {
	if (USE_CLEARCOAT) {
		clearcoatSpecularIndirect += clearcoatRadiance * EnvironmentBRDF(material.clearcoatNormal, geometryViewDir,
			material.clearcoatF0, material.clearcoatF90, material.clearcoatRoughness);
	}

	if (USE_SHEEN) {
		sheenSpecularIndirect += irradiance * material.sheenColor
			* IBLSheenBRDF(geometryNormal, geometryViewDir, material.sheenRoughness) * RECIPROCAL_PI;
	}

	// Multiple scattering for the dielectric and the metallic part, mixed by metalness.
	vec3 singleScatteringDielectric = vec3(0.0);
	vec3 multiScatteringDielectric = vec3(0.0);
	vec3 singleScatteringMetallic = vec3(0.0);
	vec3 multiScatteringMetallic = vec3(0.0);
	computeMultiscattering(material.dfg, material.specularColor, material.specularF90, material.iridescence,
		material.iridescenceF0Dielectric, singleScatteringDielectric, multiScatteringDielectric);
	computeMultiscattering(material.dfg, material.diffuseColor, material.specularF90, material.iridescence,
		material.iridescenceF0Metallic, singleScatteringMetallic, multiScatteringMetallic);

	vec3 singleScattering = mix(singleScatteringDielectric, singleScatteringMetallic, material.metalness);
	vec3 multiScattering = mix(multiScatteringDielectric, multiScatteringMetallic, material.metalness);

	// Diffuse energy conservation uses the dielectric path.
	vec3 totalScatteringDielectric = singleScatteringDielectric + multiScatteringDielectric;
	vec3 diffuse;

	if (USE_DIFFUSE_ROUGHNESS) {
		float dotNV = saturate(dot(geometryNormal, geometryViewDir));
		diffuse = EON_DirectionalAlbedo(material.diffuseColor, material.diffuseRoughness, dotNV)
			* (1.0 - material.metalness) * (1.0 - totalScatteringDielectric);
	} else {
		diffuse = material.diffuseContribution * (1.0 - totalScatteringDielectric);
	}

	vec3 cosineWeightedIrradiance = irradiance * RECIPROCAL_PI;
	vec3 indirectSpecular = radiance * singleScattering;
	indirectSpecular += multiScattering * cosineWeightedIrradiance;

	vec3 indirectDiffuse = diffuse * cosineWeightedIrradiance;

	if (USE_SHEEN) {
		float sheenAlbedo = IBLSheenBRDF(geometryNormal, geometryViewDir, material.sheenRoughness);
		float sheenEnergyComp = 1.0 - max3(material.sheenColor) * sheenAlbedo;
		indirectSpecular *= sheenEnergyComp;
		indirectDiffuse *= sheenEnergyComp;
	}

	reflectedLight.indirectSpecular += indirectSpecular;
	reflectedLight.indirectDiffuse += indirectDiffuse;
}

// Moving Frostbite to Physically Based Rendering.
float computeSpecularOcclusion(float dotNV, float ambientOcclusion, float roughness) {
	return saturate(pow(dotNV + ambientOcclusion, exp2(-16.0 * roughness - 1.0)) - 1.0 + ambientOcclusion);
}

// lights_physical_fragment's geometryRoughness: the largest change of the non-perturbed normal to the next pixel
// in x or y. Flutter GPU's dFdx and dFdy are coarse here (one value per 2 × 2 quad, from its top-left pixel;
// measured on Apple M1), while WebGL's frames match per-pixel (fine) differences, which matters for normalize(),
// the one nonlinear function the reference differentiates. So the normals of the quad neighbours in the pixel's own
// row and column are rebuilt: the varying over w and 1 / w (gl_FragCoord.w) are linear in the window, so their
// coarse derivatives give the neighbours' perspective-correct values exactly, even outside the triangle (helper
// pixels). A flat-shaded normal is constant per triangle: no change.
float geometryRoughnessOf() {
	if (normal_info.flat_shaded > 0.5) {
		return 0.0;
	}

	float b = gl_FragCoord.w;
	vec3 a = v_normal * b;
	vec2 inQuad = mod(floor(gl_FragCoord.xy), 2.0);
	vec3 ax = a - inQuad.x * dFdx(a);
	vec3 ay = a - inQuad.y * dFdy(a);
	float bx = b - inQuad.x * dFdx(b);
	float by = b - inQuad.y * dFdy(b);
	vec3 dx = normalize((ax + dFdx(a)) / (bx + dFdx(b))) - normalize(ax / bx);
	vec3 dy = normalize((ay + dFdy(a)) / (by + dFdy(b))) - normalize(ay / by);
	vec3 dxy = max(abs(dx), abs(dy));
	return max(max(dxy.x, dxy.y), dxy.z);
}

#define LIGHT_MATERIAL PhysicalMaterial
#include "shaders/lights.glsl"
#ifdef TRANSMISSION
#include "shaders/transmission.glsl"
#endif

out vec4 frag_color;

// Rect area lights (lights_physical_pars_fragment): Real-Time Polygonal-Light Shading with Linearly Transformed
// Cosines, by Eric Heitz, Jonathan Dupuy, Stephen Hill and David Neubelt (https://github.com/selfshadow/ltc_code/).
vec2 LTC_Uv(vec3 N, vec3 V, float roughness) {
	const float LUT_SIZE = 64.0;
	const float LUT_SCALE = (LUT_SIZE - 1.0) / LUT_SIZE;
	const float LUT_BIAS = 0.5 / LUT_SIZE;

	// The table is parameterized by sqrt(GGX alpha) and sqrt(1 - cos(theta)).
	vec2 uv = vec2(roughness, sqrt(1.0 - saturate(dot(N, V))));
	return uv * LUT_SCALE + LUT_BIAS;
}

// An approximation of the form factor of a horizon-clipped rectangle.
float LTC_ClippedSphereFormFactor(vec3 f) {
	float l = length(f);
	return max((l * l + f.z) / (l + 1.0), 0.0);
}

vec3 LTC_EdgeVectorFormFactor(vec3 v1, vec3 v2) {
	float x = dot(v1, v2);
	float y = abs(x);

	// A rational polynomial approximation of theta / sin(theta) / 2PI.
	float a = 0.8543985 + (0.4965155 + 0.0145206 * y) * y;
	float b = 3.4175940 + (4.1616724 + y) * y;
	float v = a / b;
	float theta_sintheta = (x > 0.0) ? v : 0.5 * inversesqrt(max(1.0 - x * x, 1e-7)) - v;
	return cross(v1, v2) * theta_sintheta;
}

vec3 LTC_Evaluate(vec3 N, vec3 V, vec3 P, mat3 mInv, vec3 rectCoords[4]) {

	// Nothing on the back side of the light's plane (counterclockwise vertices).
	vec3 v1 = rectCoords[1] - rectCoords[0];
	vec3 v2 = rectCoords[3] - rectCoords[0];

	if (dot(cross(v1, v2), P - rectCoords[0]) < 0.0) {
		return vec3(0.0);
	}

	// An orthonormal basis around N (T2 negated from the paper, as in the reference).
	vec3 T1 = normalize(V - N * dot(V, N));
	vec3 T2 = -cross(N, T1);
	mat3 mat = mInv * transpose(mat3(T1, T2, N));

	// The rect, transformed and projected onto the sphere.
	vec3 c0 = normalize(mat * (rectCoords[0] - P));
	vec3 c1 = normalize(mat * (rectCoords[1] - P));
	vec3 c2 = normalize(mat * (rectCoords[2] - P));
	vec3 c3 = normalize(mat * (rectCoords[3] - P));
	vec3 vectorFormFactor = vec3(0.0);
	vectorFormFactor += LTC_EdgeVectorFormFactor(c0, c1);
	vectorFormFactor += LTC_EdgeVectorFormFactor(c1, c2);
	vectorFormFactor += LTC_EdgeVectorFormFactor(c2, c3);
	vectorFormFactor += LTC_EdgeVectorFormFactor(c3, c0);
	return vec3(LTC_ClippedSphereFormFactor(vectorFormFactor));
}

void RE_Direct_RectArea(int i, vec3 position, vec3 normal, vec3 viewDir, PhysicalMaterial material,
		inout ReflectedLight reflectedLight) {
	vec3 lightPos = light_info.rect_position[i].xyz;
	vec3 halfWidth = light_info.rect_half_width[i].xyz;
	vec3 halfHeight = light_info.rect_half_height[i].xyz;
	vec3 lightColor = light_info.rect_color[i].xyz;

	// Counterclockwise; the light shines in its local -z direction.
	vec3 rectCoords[4];
	rectCoords[0] = lightPos + halfWidth - halfHeight;
	rectCoords[1] = lightPos - halfWidth - halfHeight;
	rectCoords[2] = lightPos - halfWidth + halfHeight;
	rectCoords[3] = lightPos + halfWidth + halfHeight;

	vec2 uv = LTC_Uv(normal, viewDir, material.roughness);
	vec4 t1 = texture(ltc_1, uv);
	vec4 t2 = texture(ltc_2, uv);
	mat3 mInv = mat3(vec3(t1.x, 0.0, t1.y), vec3(0.0, 1.0, 0.0), vec3(t1.z, 0.0, t1.w));

	// The LTC Fresnel approximation by Stephen Hill.
	vec3 fresnel = material.specularColorBlended * t2.x + (material.specularF90 - material.specularColorBlended) * t2.y;
	reflectedLight.directSpecular += lightColor * fresnel * LTC_Evaluate(normal, viewDir, position, mInv, rectCoords);
	reflectedLight.directDiffuse += lightColor * material.diffuseContribution
		* LTC_Evaluate(normal, viewDir, position, mat3(1.0), rectCoords);

	if (USE_CLEARCOAT) {
		vec3 Ncc = material.clearcoatNormal;
		vec2 uvClearcoat = LTC_Uv(Ncc, viewDir, material.clearcoatRoughness);
		vec4 t1Clearcoat = texture(ltc_1, uvClearcoat);
		vec4 t2Clearcoat = texture(ltc_2, uvClearcoat);
		mat3 mInvClearcoat = mat3(vec3(t1Clearcoat.x, 0.0, t1Clearcoat.y), vec3(0.0, 1.0, 0.0),
			vec3(t1Clearcoat.z, 0.0, t1Clearcoat.w));
		vec3 fresnelClearcoat = material.clearcoatF0 * t2Clearcoat.x
			+ (material.clearcoatF90 - material.clearcoatF0) * t2Clearcoat.y;
		clearcoatSpecularDirect += lightColor * fresnelClearcoat
			* LTC_Evaluate(Ncc, viewDir, position, mInvClearcoat, rectCoords);
	}
}

void main() {
#ifdef SLOT_MAPS
	readSlots();
#endif
	vec4 diffuseColor = diffuseOf(vec4(frag_info.diffuse, frag_info.opacity));
	ReflectedLight reflectedLight = ReflectedLight(vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));

	// roughnessmap_fragment (channel G) and metalnessmap_fragment (channel B).
	float roughnessFactor = frag_info.roughness;

	if (useMap(0)) {
		roughnessFactor *= texture(roughness_map, mapUv(0)).g;
	}

	float metalnessFactor = frag_info.metalness;

	if (useMap(1)) {
		metalnessFactor *= texture(metalness_map, mapUv(1)).b;
	}

	// normal_fragment_begin with the tangent frames of the normal map, the clearcoat normal map and anisotropy.
	float faceDirection = gl_FrontFacing ? 1.0 : -1.0;
	vec3 normal = beginNormal(faceDirection);
	bool clearcoatNormalMap = USE_CLEARCOAT && useMap(4);
	mat3 tbn = mat3(1.0);

#ifdef USE_NORMALMAP_TANGENTSPACE
	tbn = tangentFrame(normal, v_normal_map_uv, faceDirection);
#elif defined(USE_NORMALMAP_OBJECTSPACE)
	if (clearcoatNormalMap || USE_ANISOTROPY) {
		tbn = tangentFrame(normal, v_normal_map_uv, faceDirection);
	}
#else
	if (clearcoatNormalMap || USE_ANISOTROPY) {
		tbn = tangentFrame(normal, clearcoatNormalMap ? mapUv(4) : v_uv.xy, faceDirection);
	}
#endif

	mat3 tbn2 = clearcoatNormalMap ? tangentFrame(normal, mapUv(4), faceDirection) : mat3(1.0);
	vec3 nonPerturbedNormal = normal;
	normal = mapNormal(normal, tbn, faceDirection);

	// clearcoat_normal_fragment_begin and _maps.
	vec3 clearcoatNormal = nonPerturbedNormal;

#ifdef PHYSICAL
	if (clearcoatNormalMap) {
		vec3 clearcoatMapN = texture(clearcoat_normal_map, mapUv(4)).xyz * 2.0 - 1.0;
		clearcoatMapN.xy *= frag_info.clearcoat_normal_scale;
		clearcoatNormal = normalize(tbn2 * clearcoatMapN);
	}
#endif

	vec3 totalEmissiveRadiance = emissiveOf(frag_info.emissive);

	// lights_physical_fragment.
	PhysicalMaterial material;
	material.diffuseColor = diffuseColor.rgb;
	material.diffuseContribution = diffuseColor.rgb * (1.0 - metalnessFactor);
	material.metalness = metalnessFactor;

	float geometryRoughness = geometryRoughnessOf();

	// A minimum roughness, so even a perfect mirror samples a prefiltered level of the environment map
	// (Filament's MIN_PERCEPTUAL_ROUGHNESS).
	material.roughness = max(roughnessFactor, 0.045);
	material.roughness += geometryRoughness;
	material.roughness = min(material.roughness, 1.0);

#ifdef PHYSICAL
	if (USE_DIFFUSE_ROUGHNESS) {
		float diffuseRoughnessFactor = frag_info.diffuse_roughness;

		if (useMap(12)) {
			diffuseRoughnessFactor *= texture(diffuse_roughness_map, mapUv(12)).r;
		}

		material.diffuseRoughness = saturate(diffuseRoughnessFactor);
	}
#endif

	material.ior = frag_info.ior;

	float specularIntensityFactor = frag_info.specular_intensity;
	vec3 specularColorFactor = frag_info.specular_color;

#ifdef PHYSICAL
	if (useMap(11)) {
		specularColorFactor *= texture(specular_color_map, mapUv(11)).rgb;
	}

	if (useMap(10)) {
		specularIntensityFactor *= texture(specular_intensity_map, mapUv(10)).a;
	}
#endif

	material.specularF90 = mix(specularIntensityFactor, 1.0, metalnessFactor);
	material.specularColor = min(pow2((material.ior - 1.0) / (material.ior + 1.0)) * specularColorFactor, vec3(1.0))
		* specularIntensityFactor;
	material.specularColorBlended = mix(material.specularColor, diffuseColor.rgb, metalnessFactor);

	material.clearcoatNormal = vec3(0.0);

#ifdef PHYSICAL
	if (USE_CLEARCOAT) {
		material.clearcoat = frag_info.clearcoat;
		material.clearcoatRoughness = frag_info.clearcoat_roughness;
		material.clearcoatF0 = vec3(0.04);
		material.clearcoatF90 = 1.0;

		if (useMap(2)) {
			material.clearcoat *= texture(clearcoat_map, mapUv(2)).x;
		}

		if (useMap(3)) {
			material.clearcoatRoughness *= texture(clearcoat_roughness_map, mapUv(3)).y;
		}

		// The Burley clearcoat model.
		material.clearcoat = saturate(material.clearcoat);
		material.clearcoatRoughness = max(material.clearcoatRoughness, 0.045);
		material.clearcoatRoughness += geometryRoughness;
		material.clearcoatRoughness = min(material.clearcoatRoughness, 1.0);
		material.clearcoatNormal = clearcoatNormal;
	}
#endif

	material.dispersion = frag_info.dispersion;
	material.retroreflectivity = frag_info.retroreflectivity;
	material.iridescence = 0.0;
	material.iridescenceF0Dielectric = vec3(0.0);
	material.iridescenceF0Metallic = vec3(0.0);

#ifdef PHYSICAL
	if (USE_IRIDESCENCE) {
		material.iridescence = frag_info.iridescence;
		material.iridescenceIOR = frag_info.iridescence_ior;

		if (useMap(7)) {
			material.iridescence *= texture(iridescence_map, mapUv(7)).r;
		}

		material.iridescenceThickness = useMap(8)
			? (frag_info.iridescence_thickness_maximum - frag_info.iridescence_thickness_minimum)
				* texture(iridescence_thickness_map, mapUv(8)).g + frag_info.iridescence_thickness_minimum
			: frag_info.iridescence_thickness_maximum;
	}

	if (USE_SHEEN) {
		material.sheenColor = frag_info.sheen_color;

		if (useMap(5)) {
			material.sheenColor *= texture(sheen_color_map, mapUv(5)).rgb;
		}

		material.sheenRoughness = clamp(frag_info.sheen_roughness, 0.0001, 1.0);

		if (useMap(6)) {
			material.sheenRoughness *= texture(sheen_roughness_map, mapUv(6)).a;
		}
	}

	if (USE_ANISOTROPY) {
		vec2 anisotropyV;

		if (useMap(9)) {
			vec2 v = frag_info.anisotropy_vector;
			mat2 anisotropyMat = mat2(v.x, v.y, -v.y, v.x);
			vec3 anisotropyPolar = texture(anisotropy_map, mapUv(9)).rgb;
			anisotropyV = anisotropyMat * normalize(2.0 * anisotropyPolar.rg - vec2(1.0)) * anisotropyPolar.b;
		} else {
			anisotropyV = frag_info.anisotropy_vector;
		}

		material.anisotropy = length(anisotropyV);

		if (material.anisotropy == 0.0) {
			anisotropyV = vec2(1.0, 0.0);
		} else {
			anisotropyV /= material.anisotropy;
			material.anisotropy = saturate(material.anisotropy);
		}

		// Roughness along the bitangent is the material's; along the tangent it grows with anisotropy.
		material.alphaT = mix(pow2(material.roughness), 1.0, pow2(material.anisotropy));
		material.anisotropyT = tbn[0] * anisotropyV.x + tbn[1] * anisotropyV.y;
		material.anisotropyB = tbn[1] * anisotropyV.x - tbn[0] * anisotropyV.y;
	}
#endif

	// lights_fragment_begin.
	vec3 geometryPosition = -v_view_position;
	vec3 geometryNormal = normal;
	vec3 viewDir = geometryViewDir();

	if (USE_IRIDESCENCE) {
		float dotNVi = saturate(dot(normal, viewDir));

		if (material.iridescenceThickness == 0.0) {
			material.iridescence = 0.0;
		} else {
			material.iridescence = saturate(material.iridescence);
		}

		if (material.iridescence > 0.0) {
			vec3 dielectric = evalIridescence(1.0, material.iridescenceIOR, dotNVi, material.iridescenceThickness,
				material.specularColor);
			vec3 metallic = evalIridescence(1.0, material.iridescenceIOR, dotNVi, material.iridescenceThickness,
				material.diffuseColor);
			material.iridescenceFresnel = mix(dielectric, metallic, material.metalness);

			// The iridescence F0 approximation.
			material.iridescenceF0Dielectric = Schlick_to_F0(dielectric, 1.0, dotNVi);
			material.iridescenceF0Metallic = Schlick_to_F0(metallic, 1.0, dotNVi);
		}
	}

	float dotNVms = saturate(dot(geometryNormal, viewDir));
	material.dfg = texture(dfg_lut, vec2(material.roughness, dotNVms)).rg;

	// Multiple-scattering energy compensation for direct light (Turquin, equation 16): the energy of the
	// single-scattering lobe in a white furnace, tinted by F0.
	float EssMs = material.dfg.x + material.dfg.y;
	material.multiScatteringCompensation = 1.0 + material.specularColorBlended * (1.0 / EssMs - 1.0);

	directLights(geometryPosition, geometryNormal, viewDir, material, reflectedLight);

	for (int i = 0; i < MAX_RECT_AREA_LIGHTS; i++) {
		if (float(i) >= light_info.rect_areas) {
			break;
		}

		RE_Direct_RectArea(i, geometryPosition, geometryNormal, viewDir, material, reflectedLight);
	}

	// The indirect light: ambient, probes, hemisphere lights and the lightMap (lights_fragment_maps), image-based
	// irradiance and radiance from the PMREM, and lights_fragment_end.
	vec3 irradiance = indirectIrradiance(geometryNormal) + lightMapIrradiance();
	vec3 iblIrradiance = getIBLIrradiance(geometryNormal);
	vec3 radiance = vec3(0.0);
	vec3 clearcoatRadiance = vec3(0.0);

	if (env_info.env_type > 0.5) {
		bool anisotropic = USE_ANISOTROPY;
		vec3 bent = anisotropic
			? anisotropyBentNormal(viewDir, geometryNormal, material.roughness, material.anisotropyB, material.anisotropy)
			: geometryNormal;
		vec3 iblRadiance = getIBLRadiance(viewDir, bent, material.roughness);

		if (frag_info.retroreflectivity > 0.0) {
			vec3 retroIBLRadiance = getIBLRetroRadiance(viewDir, bent, material.roughness);
			iblRadiance = mix(iblRadiance, retroIBLRadiance, saturate(material.retroreflectivity));
		}

		radiance += iblRadiance;

		if (USE_CLEARCOAT) {
			clearcoatRadiance += getIBLRadiance(viewDir, clearcoatNormal, material.clearcoatRoughness);
		}
	}

	RE_IndirectDiffuse(irradiance, geometryNormal, viewDir, material, reflectedLight);
	RE_IndirectSpecular(radiance, iblIrradiance, clearcoatRadiance, geometryNormal, viewDir, material, reflectedLight);

	// aomap_fragment.
#ifdef USE_AOMAP
	float ambientOcclusion = ambientOcclusion();
	reflectedLight.indirectDiffuse *= ambientOcclusion;

	if (USE_CLEARCOAT) {
		clearcoatSpecularIndirect *= ambientOcclusion;
	}

	if (USE_SHEEN) {
		sheenSpecularIndirect *= ambientOcclusion;
	}

	if (env_info.env_type > 0.5) {
		float dotNV = saturate(dot(geometryNormal, viewDir));
		reflectedLight.indirectSpecular *= computeSpecularOcclusion(dotNV, ambientOcclusion, material.roughness);
	}
#endif

	vec3 totalDiffuse = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse;
	vec3 totalSpecular = reflectedLight.directSpecular + reflectedLight.indirectSpecular;

	material.transmissionAlpha = 1.0;

#ifdef TRANSMISSION
	if (USE_TRANSMISSION) {
		totalDiffuse = transmit(material, normal, totalDiffuse);
	}
#endif

	vec3 outgoingLight = totalDiffuse + totalSpecular + totalEmissiveRadiance;

	if (USE_SHEEN) {
		outgoingLight = outgoingLight + sheenSpecularDirect + sheenSpecularIndirect;
	}

	if (USE_CLEARCOAT) {
		float dotNVcc = saturate(dot(clearcoatNormal, viewDir));
		vec3 Fcc = F_Schlick(material.clearcoatF0, material.clearcoatF90, dotNVcc);
		outgoingLight = outgoingLight * (1.0 - material.clearcoat * Fcc)
			+ (clearcoatSpecularDirect + clearcoatSpecularIndirect) * material.clearcoat;
	}

	// opaque_fragment with USE_TRANSMISSION's alpha.
	float alpha = output_info.opaque > 0.5 ? 1.0 : diffuseColor.a;
	frag_color = finishColor(vec4(outgoingLight, alpha * material.transmissionAlpha), v_view_position.z);
	applyPolygonOffset();
}
