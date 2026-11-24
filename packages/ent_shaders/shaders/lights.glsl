// The reference's lights_pars_begin and lights_fragment_begin for the lights it collects: ambient, light
// probes, hemisphere, directional, point and spot lights, in view space. The reference unrolls a loop per light
// type with NUM_*_LIGHTS defines; here the counts are uniforms bounded by fixed maximums (exception
// E-SHADERS), and the uniform arrays are vec4s: xyz the vector, w a scalar where noted. Directional, spot and
// point lights apply their shadow maps (shadowmap_pars_fragment, shadowmap_vertex), spot lights their
// SpotLight.map.
//
// Include after shaders/common.glsl, with LIGHT_MATERIAL defined as the material's struct and RE_Direct
// declared for it, as the lights_*_pars_fragment chunks do. Without LIGHT_MATERIAL (shaders/shadow.glsl) only the
// light uniforms and the shadow lookups are declared: no directLights, no lightMap (MapInfo is not included).
#define MAX_DIRECTIONAL_LIGHTS 4
#define MAX_POINT_LIGHTS 8
#define MAX_SPOT_LIGHTS 4
#define MAX_HEMI_LIGHTS 2
#define MAX_RECT_AREA_LIGHTS 2

uniform LightInfo {

	// The camera's matrixWorldInverse, for light probes (transformNormalByInverseViewMatrix).
	mat4 view_matrix;
	vec3 ambient_light_color;

	// 1 for an orthographic camera (geometryViewDir is +z), else 0.
	float is_orthographic;

	// The summed spherical harmonics of the light probes (USE_LIGHT_PROBES when light_probes is 1).
	vec4 light_probe[9];
	float light_probes;

	// receiveShadow, 1 or 0.
	float receive_shadow;

	// Lights of each type in use: directional, point, spot, hemisphere.
	vec4 light_counts;

	vec4 directional_direction[MAX_DIRECTIONAL_LIGHTS];
	vec4 directional_color[MAX_DIRECTIONAL_LIGHTS];

	// position: xyz and distance in w; color: rgb and decay in w.
	vec4 point_position[MAX_POINT_LIGHTS];
	vec4 point_color[MAX_POINT_LIGHTS];

	// position: xyz and distance in w; direction: xyz and decay in w; cone: coneCos, penumbraCos.
	vec4 spot_position[MAX_SPOT_LIGHTS];
	vec4 spot_direction[MAX_SPOT_LIGHTS];
	vec4 spot_color[MAX_SPOT_LIGHTS];
	vec4 spot_cone[MAX_SPOT_LIGHTS];

	vec4 hemi_direction[MAX_HEMI_LIGHTS];
	vec4 hemi_sky_color[MAX_HEMI_LIGHTS];
	vec4 hemi_ground_color[MAX_HEMI_LIGHTS];

	// NUM_RECT_AREA_LIGHTS, and per light the view-space position, halfWidth and halfHeight, and color (xyz);
	// only the physical program reads them (RE_Direct_RectArea).
	float rect_areas;
	vec4 rect_position[MAX_RECT_AREA_LIGHTS];
	vec4 rect_half_width[MAX_RECT_AREA_LIGHTS];
	vec4 rect_half_height[MAX_RECT_AREA_LIGHTS];
	vec4 rect_color[MAX_RECT_AREA_LIGHTS];

	// NUM_DIR_LIGHT_SHADOWS (the first directional lights cast them; 0 without USE_SHADOWMAP), the shadow map
	// type (0 SHADOWMAP_TYPE_BASIC, 1 SHADOWMAP_TYPE_PCF, 2 SHADOWMAP_TYPE_VSM), the target's height (gl_FragCoord
	// in GL's orientation) and HAS_NORMAL.
	vec4 shadow_info;

	// directionalShadowMatrix, and per light shadowIntensity, shadowBias, shadowNormalBias, shadowRadius;
	// shadowMapSize in xy and the map's light texture in z.
	mat4 directional_shadow_matrix[MAX_DIRECTIONAL_LIGHTS];
	vec4 directional_shadow[MAX_DIRECTIONAL_LIGHTS];
	vec4 directional_shadow_size[MAX_DIRECTIONAL_LIGHTS];

	// NUM_SPOT_LIGHT_SHADOWS (the first spot lights cast them), spotLightMatrix per spot light, the shadows as
	// directional_shadow, and per spot light shadowMapSize in xy, the shadow map's light texture in z and its
	// SpotLight.map's in w (−1 for none; the reference's SPOT_LIGHT_MAP_INDEX).
	float spot_shadows;
	mat4 spot_light_matrix[MAX_SPOT_LIGHTS];
	vec4 spot_shadow[MAX_SPOT_LIGHTS];
	vec4 spot_shadow_size[MAX_SPOT_LIGHTS];

	// NUM_POINT_LIGHT_SHADOWS (the first point lights cast them), the shadows as directional_shadow; per light
	// shadowMapSize.x in x, the map's light texture in y, shadowCameraNear and shadowCameraFar in z and w; and the
	// light's world position (pointShadowMatrix is the translation to it).
	float point_shadows;
	vec4 point_shadow[MAX_POINT_LIGHTS];
	vec4 point_shadow_size[MAX_POINT_LIGHTS];
	vec4 point_shadow_position[MAX_POINT_LIGHTS];
} light_info;

// directionalShadowMap and spotShadowMap: the depth of each shadow map in r (a float target; Flutter GPU has no
// comparison samplers), read with nearest filtering; and spotLightMap, the textures spot lights project. One pool
// of slots for both, at most MAX_LIGHT_TEXTURES together (a Metal fragment stage binds 31 textures, which the
// physical program reaches with these), each light naming its slots. Separate samplers: an array of them is not
// portable through impellerc.
#define MAX_LIGHT_TEXTURES 6

// A stage that reads its textures through slots (slots.glsl, the physical one) reads light texture k from slot_k, so
// it declares none of these: the compiler would drop them, its reflection would keep them all at binding 0, and a
// Vulkan descriptor layout that repeats a binding hung the Galaxy S10 (Mali-G76).
#ifndef TEXTURE_SLOTS
uniform sampler2D light_texture_0;
uniform sampler2D light_texture_1;
uniform sampler2D light_texture_2;
uniform sampler2D light_texture_3;
uniform sampler2D light_texture_4;
uniform sampler2D light_texture_5;
#endif

// Light texture [slot] at [uv], in uniform control flow wherever the texture has mipmaps.
vec4 lightTexture(int slot, vec2 uv) {
	if (slot == 0) {
		return texture(light_texture_0, uv);
	}

	if (slot == 1) {
		return texture(light_texture_1, uv);
	}

	if (slot == 2) {
		return texture(light_texture_2, uv);
	}

	if (slot == 3) {
		return texture(light_texture_3, uv);
	}

	if (slot == 4) {
		return texture(light_texture_4, uv);
	}

	return texture(light_texture_5, uv);
}

// The irradiance (radiance convolved with the cosine lobe) at [normal] (unit length) on the unit sphere.
vec3 shGetIrradianceAt(vec3 normal) {
	float x = normal.x, y = normal.y, z = normal.z;
	vec3 result = light_info.light_probe[0].xyz * 0.886227;
	result += light_info.light_probe[1].xyz * 2.0 * 0.511664 * y;
	result += light_info.light_probe[2].xyz * 2.0 * 0.511664 * z;
	result += light_info.light_probe[3].xyz * 2.0 * 0.511664 * x;
	result += light_info.light_probe[4].xyz * 2.0 * 0.429043 * x * y;
	result += light_info.light_probe[5].xyz * 2.0 * 0.429043 * y * z;
	result += light_info.light_probe[6].xyz * (0.743125 * z * z - 0.247708);
	result += light_info.light_probe[7].xyz * 2.0 * 0.429043 * x * z;
	result += light_info.light_probe[8].xyz * 0.429043 * (x * x - y * y);
	return result;
}

vec3 getLightProbeIrradiance(vec3 normal) {
	vec3 worldNormal = normalize((vec4(normal, 0.0) * light_info.view_matrix).xyz);
	return shGetIrradianceAt(worldNormal);
}

// Frostbite's windowed inverse-square falloff (Moving Frostbite to PBR, equation 26).
float getDistanceAttenuation(float lightDistance, float cutoffDistance, float decayExponent) {
	float distanceFalloff = 1.0 / max(pow(lightDistance, decayExponent), 0.01);

	if (cutoffDistance > 0.0) {
		distanceFalloff *= pow2(saturate(1.0 - pow4(lightDistance / cutoffDistance)));
	}

	return distanceFalloff;
}

float getSpotAttenuation(float coneCosine, float penumbraCosine, float angleCosine) {
	return smoothstep(coneCosine, penumbraCosine, angleCosine);
}

void getDirectionalLightInfo(int i, out IncidentLight light) {
	light.color = light_info.directional_color[i].rgb;
	light.direction = light_info.directional_direction[i].xyz;
	light.visible = true;
}

void getPointLightInfo(int i, vec3 geometryPosition, out IncidentLight light) {
	vec3 lVector = light_info.point_position[i].xyz - geometryPosition;
	light.direction = normalize(lVector);

	float lightDistance = length(lVector);
	light.color = light_info.point_color[i].rgb;
	light.color *= getDistanceAttenuation(lightDistance, light_info.point_position[i].w, light_info.point_color[i].w);
	light.visible = (light.color != vec3(0.0));
}

void getSpotLightInfo(int i, vec3 geometryPosition, out IncidentLight light) {
	vec3 lVector = light_info.spot_position[i].xyz - geometryPosition;
	light.direction = normalize(lVector);

	float angleCos = dot(light.direction, light_info.spot_direction[i].xyz);
	float spotAttenuation = getSpotAttenuation(light_info.spot_cone[i].x, light_info.spot_cone[i].y, angleCos);

	if (spotAttenuation > 0.0) {
		float lightDistance = length(lVector);
		light.color = light_info.spot_color[i].rgb * spotAttenuation;
		light.color *= getDistanceAttenuation(lightDistance, light_info.spot_position[i].w, light_info.spot_direction[i].w);
		light.visible = (light.color != vec3(0.0));
	} else {
		light.color = vec3(0.0);
		light.visible = false;
	}
}

vec3 getHemisphereLightIrradiance(int i, vec3 normal) {
	float dotNL = dot(normal, light_info.hemi_direction[i].xyz);
	float hemiDiffuseWeight = 0.5 * dotNL + 0.5;
	return mix(light_info.hemi_ground_color[i].rgb, light_info.hemi_sky_color[i].rgb, hemiDiffuseWeight);
}

// Interleaved Gradient Noise, to rotate the PCF samples per pixel (shadowmap_pars_fragment).
float interleavedGradientNoise(vec2 position) {
	return fract(52.9829189 * fract(dot(position, vec2(0.06711056, 0.00583715))));
}

// Vogel disk sampling for a uniform circular distribution.
vec2 vogelDiskSample(int sampleIndex, int samplesCount, float phi) {

	// The golden angle, 2.399963229728653.
	float theta = float(sampleIndex) * 2.399963229728653 + phi;
	return vec2(cos(theta), sin(theta)) * sqrt((float(sampleIndex) + 0.5) / float(samplesCount));
}

// A shadow map's (s, t) for [uv] in its GL orientation (v up): v is mirrored where rendered maps have their first
// row at the top (output_info.target_rows -1).
vec2 shadowUv(vec2 uv) {
	return vec2(uv.x, output_info.target_rows < 0.0 ? 1.0 - uv.y : uv.y);
}

// The pixel's window position as WebGL counts it, from the bottom: gl_FragCoord's y is mirrored where rows run down
// (light_info.shadow_info.z is the target's height).
vec2 windowGL() {
	return vec2(gl_FragCoord.x, output_info.rows < 0.0 ? light_info.shadow_info.z - gl_FragCoord.y : gl_FragCoord.y);
}

// A sampler2DShadow lookup with LessEqualCompare and LinearFilter: the four nearest texels compared with
// [depth], weighted bilinearly, as the hardware filters comparisons. [uv] is in the map's GL orientation (v up);
// where rendered maps have their first row at the top (output_info.target_rows -1), v is mirrored.
float shadowCompare(int shadowMap, vec2 shadowMapSize, vec2 uv, float depth) {
	vec2 p = shadowUv(uv) * shadowMapSize - 0.5;
	vec2 f = fract(p);
	vec2 c = (floor(p) + 0.5) / shadowMapSize;
	vec2 t = 1.0 / shadowMapSize;
	return mix(
		mix(step(depth, lightTexture(shadowMap, c).r), step(depth, lightTexture(shadowMap, c + vec2(t.x, 0.0)).r), f.x),
		mix(step(depth, lightTexture(shadowMap, c + vec2(0.0, t.y)).r), step(depth, lightTexture(shadowMap, c + t).r), f.x),
		f.y
	);
}

// getShadow of shadowmap_pars_fragment for SHADOWMAP_TYPE_VSM (type 2), SHADOWMAP_TYPE_PCF (type 1) and
// SHADOWMAP_TYPE_BASIC (type 0).
float getShadow(int shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius,
		vec4 shadowCoord) {
	float shadow = 1.0;
	shadowCoord.xyz /= shadowCoord.w;
	shadowCoord.z += shadowBias;

	// The frustum test.
	if (shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0
			&& shadowCoord.z <= 1.0) {
		if (light_info.shadow_info.y > 1.5) {

			// SHADOWMAP_TYPE_VSM: the blurred mean and standard deviation (LinearFilter), Chebyshev's upper bound
			// on the lit fraction, light bleeding reduced by remapping [0.3, 0.95] to [0, 1].
			vec2 distribution = lightTexture(shadowMap, shadowUv(shadowCoord.xy)).rg;
			float mean = distribution.x;
			float variance = distribution.y * distribution.y;
			float hard_shadow = step(shadowCoord.z, mean);

			if (hard_shadow == 1.0) {
				shadow = 1.0;
			} else {
				variance = max(variance, 0.0000001);
				float d = shadowCoord.z - mean;
				float p_max = variance / (variance + d * d);
				p_max = clamp((p_max - 0.3) / 0.65, 0.0, 1.0);
				shadow = max(hard_shadow, p_max);
			}
		} else if (light_info.shadow_info.y > 0.5) {

			// Hardware PCF with LinearFilter: 4 taps per sample, 5 samples on a Vogel disk rotated per pixel by IGN.
			vec2 radius = shadowRadius / shadowMapSize;
			float phi = interleavedGradientNoise(windowGL()) * PI2;

			shadow = (
				shadowCompare(shadowMap, shadowMapSize, shadowCoord.xy + vogelDiskSample(0, 5, phi) * radius, shadowCoord.z)
					+ shadowCompare(shadowMap, shadowMapSize, shadowCoord.xy + vogelDiskSample(1, 5, phi) * radius, shadowCoord.z)
					+ shadowCompare(shadowMap, shadowMapSize, shadowCoord.xy + vogelDiskSample(2, 5, phi) * radius, shadowCoord.z)
					+ shadowCompare(shadowMap, shadowMapSize, shadowCoord.xy + vogelDiskSample(3, 5, phi) * radius, shadowCoord.z)
					+ shadowCompare(shadowMap, shadowMapSize, shadowCoord.xy + vogelDiskSample(4, 5, phi) * radius, shadowCoord.z)
			) * 0.2;
		} else {
			shadow = step(shadowCoord.z, lightTexture(shadowMap, shadowUv(shadowCoord.xy)).r);
		}
	}

	return mix(1.0, shadow, shadowIntensity);
}

// shadowWorldNormal of shadowmap_vertex: the world normal (transformNormalByInverseViewMatrix of the vertex
// normal), 0 without HAS_NORMAL.
vec3 shadowWorldNormal() {
	return light_info.shadow_info.w > 0.5 ? (vec4(v_normal, 0.0) * light_info.view_matrix).xyz : vec3(0.0);
}

// The shadow of directional light [i]: shadowmap_vertex's vDirectionalShadowCoord, computed here from the
// interpolated world position and normal (both linear, so the result is the same), then getShadow.
float getDirectionalShadow(int i) {

	// shadowWorldNormal times shadowNormalBias offsets the world position.
	vec4 shadow = light_info.directional_shadow[i];
	vec4 coord = light_info.directional_shadow_matrix[i] * vec4(v_world_position + shadowWorldNormal() * shadow.z, 1.0);
	vec4 size = light_info.directional_shadow_size[i];
	return getShadow(int(size.z), size.xy, shadow.x, shadow.y, shadow.w, coord);
}

// vSpotLightCoord[i] of shadowmap_vertex, computed here from the interpolated world position (the same value,
// both being linear), offset along the normal by shadowNormalBias for a shadowed light.
vec4 spotLightCoord(int i, bool shadowed) {
	vec3 offset = shadowed ? shadowWorldNormal() * light_info.spot_shadow[i].z : vec3(0.0);
	return light_info.spot_light_matrix[i] * vec4(v_world_position + offset, 1.0);
}

// The color the SpotLight.map in light texture [slot] projects at [coord] (lights_fragment_begin): white outside
// the shadow camera's frustum.
vec3 spotLightMapColor(int slot, vec4 coord) {
	vec3 spotCoord = coord.xyz / coord.w;
	vec3 color = lightTexture(slot, spotCoord.xy).rgb;
	return all(lessThan(abs(spotCoord * 2.0 - 1.0), vec3(1.0))) ? color : vec3(1.0);
}

// The shadow of spot light [i] at [coord] (getShadow with spotShadowMap[i]).
float getSpotShadow(int i, vec4 coord) {
	vec4 shadow = light_info.spot_shadow[i];
	vec4 size = light_info.spot_shadow_size[i];
	return getShadow(int(size.z), size.xy, shadow.x, shadow.y, shadow.w, coord);
}

// The face of a cube map that direction [d] selects and its (s, t) in [0, 1], by the GL cube map table (the major
// axis; t up, the first row of a face being t = 0).
vec3 cubeFace(vec3 d) {
	vec3 a = abs(d);

	if (a.x >= a.y && a.x >= a.z) {
		return d.x > 0.0 ? vec3(0.0, 0.5 - 0.5 * d.z / a.x, 0.5 - 0.5 * d.y / a.x)
			: vec3(1.0, 0.5 + 0.5 * d.z / a.x, 0.5 - 0.5 * d.y / a.x);
	}

	if (a.y >= a.z) {
		return d.y > 0.0 ? vec3(2.0, 0.5 + 0.5 * d.x / a.y, 0.5 + 0.5 * d.z / a.y)
			: vec3(3.0, 0.5 + 0.5 * d.x / a.y, 0.5 - 0.5 * d.z / a.y);
	}

	return d.z > 0.0 ? vec3(4.0, 0.5 + 0.5 * d.x / a.z, 0.5 - 0.5 * d.y / a.z)
		: vec3(5.0, 0.5 - 0.5 * d.x / a.z, 0.5 - 0.5 * d.y / a.z);
}

// The depth stored at [texel] (t up, clamped to the face's edge) of face [face] of the point shadow map in light
// texture [slot]: the faces lie side by side, each [size] texels square, its row t the map's row t where rows run up
// (output_info.target_rows 1) and the mirrored one where they run down.
float pointDepth(int slot, float size, float face, vec2 texel) {
	vec2 c = clamp(texel, 0.0, size - 1.0);
	float row = output_info.target_rows < 0.0 ? size - c.y - 0.5 : c.y + 0.5;
	return lightTexture(slot, vec2(face * size + c.x + 0.5, row) / vec2(6.0 * size, size)).r;
}

// The direction of the cube map point at (s, t) of face [face] (cubeFace's inverse; s and t may lie outside [0, 1],
// on the face's plane extended).
vec3 cubeDirection(float face, vec2 st) {
	vec2 c = st * 2.0 - 1.0;

	if (face < 0.5) {
		return vec3(1.0, -c.y, -c.x);
	}

	if (face < 1.5) {
		return vec3(-1.0, -c.y, c.x);
	}

	if (face < 2.5) {
		return vec3(c.x, 1.0, c.y);
	}

	if (face < 3.5) {
		return vec3(c.x, -1.0, -c.y);
	}

	return face < 4.5 ? vec3(c.x, -c.y, 1.0) : vec3(-c.x, -c.y, -1.0);
}

// The depth of texel [texel] of face [face] as seamless cube sampling reads it: a texel past the face's edge is
// taken from the neighbouring face, where the direction of its centre falls.
float pointTexel(int slot, float size, float face, vec2 texel) {
	vec3 f = cubeFace(cubeDirection(face, (texel + 0.5) / size));
	return pointDepth(slot, size, f.x, floor(f.yz * size));
}

// A samplerCubeShadow lookup with LessEqualCompare and LinearFilter in direction [d]: the four nearest texels of
// the face [d] selects compared with [depth], weighted bilinearly, those past its edge read from the neighbouring
// faces (WebGL 2's cube maps are always seamless).
float pointCompare(int slot, float size, vec3 d, float depth) {
	vec3 f = cubeFace(d);
	vec2 p = f.yz * size - 0.5;
	vec2 w = fract(p);
	vec2 c = floor(p);
	return mix(
		mix(
			step(depth, pointTexel(slot, size, f.x, c)),
			step(depth, pointTexel(slot, size, f.x, c + vec2(1.0, 0.0))),
			w.x
		),
		mix(
			step(depth, pointTexel(slot, size, f.x, c + vec2(0.0, 1.0))),
			step(depth, pointTexel(slot, size, f.x, c + 1.0)),
			w.x
		),
		w.y
	);
}

// getPointShadow of shadowmap_pars_fragment for SHADOWMAP_TYPE_PCF (type 1) and SHADOWMAP_TYPE_BASIC and point
// light [i]: vPointShadowCoord (the vector from the light to the world position offset by shadowNormalBias)
// computed here; each face stores the perspective depth along its own axis, the major component of the vector.
float getPointShadow(int i) {
	vec4 shadow = light_info.point_shadow[i];
	vec4 size = light_info.point_shadow_size[i];
	vec3 lightToPosition = v_world_position + shadowWorldNormal() * shadow.z - light_info.point_shadow_position[i].xyz;
	vec3 a = abs(lightToPosition);
	float viewSpaceZ = max(max(a.x, a.y), a.z);
	float near = size.z;
	float far = size.w;
	float result = 1.0;

	if (viewSpaceZ - far <= 0.0 && viewSpaceZ - near >= 0.0) {
		vec3 bd3D = normalize(lightToPosition);

		if (light_info.shadow_info.y > 0.5) {

			// Each of 5 samples on a Vogel disk (rotated per pixel by IGN, radius texels wide in the tangent plane)
			// is compared with the depth of the point next to the fragment in its direction, on whichever face it
			// falls: lightDistance times the major component of the direction, as perspective depth a + b / z.
			float range = far - near;
			float depthA = far / range + shadow.y;
			float depthB = -near * far / (range * length(lightToPosition));
			float texelSize = shadow.w / size.x;
			vec3 absDir = abs(bd3D);
			vec3 tangent = normalize(cross(bd3D, absDir.x > absDir.z ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
			vec3 bitangent = cross(bd3D, tangent);
			float phi = interleavedGradientNoise(windowGL()) * PI2;
			result = 0.0;

			for (int k = 0; k < 5; k++) {
				vec2 offset = vogelDiskSample(k, 5, phi);
				vec3 direction = bd3D + (tangent * offset.x + bitangent * offset.y) * texelSize;
				vec3 d = abs(direction);
				result += pointCompare(int(size.y), size.x, direction, depthA + depthB / max(max(d.x, d.y), d.z));
			}

			result *= 0.2;
		} else {
			float dp = (far * (viewSpaceZ - near)) / (viewSpaceZ * (far - near)) + shadow.y;
			vec3 f = cubeFace(bd3D);
			result = step(dp, pointDepth(int(size.y), size.x, f.x, floor(f.yz * size.x)));
		}
	}

	return mix(1.0, result, shadow.x);
}

// geometryViewDir of lights_fragment_begin.
vec3 geometryViewDir() {
	return light_info.is_orthographic > 0.5 ? vec3(0.0, 0.0, 1.0) : normalize(v_view_position);
}

#ifdef LIGHT_MATERIAL
// The direct part of lights_fragment_begin: point, spot, then directional lights, each through RE_Direct.
void directLights(vec3 geometryPosition, vec3 geometryNormal, vec3 viewDir, LIGHT_MATERIAL material,
		inout ReflectedLight reflectedLight) {
	IncidentLight directLight;

	for (int i = 0; i < MAX_POINT_LIGHTS; i++) {
		if (float(i) >= light_info.light_counts.y) {
			break;
		}

		getPointLightInfo(i, geometryPosition, directLight);

		if (float(i) < light_info.point_shadows && directLight.visible && light_info.receive_shadow > 0.5) {
			directLight.color *= getPointShadow(i);
		}

		RE_Direct(directLight, geometryPosition, geometryNormal, viewDir, material, reflectedLight);
	}

	for (int i = 0; i < MAX_SPOT_LIGHTS; i++) {
		if (float(i) >= light_info.light_counts.z) {
			break;
		}

		getSpotLightInfo(i, geometryPosition, directLight);

		// The projected map, then the shadow, through the shared spotLightMatrix.
		bool shadowed = float(i) < light_info.spot_shadows;
		int slot = int(light_info.spot_shadow_size[i].w);

		if (shadowed || slot >= 0) {
			vec4 coord = spotLightCoord(i, shadowed);

			if (slot >= 0) {
				directLight.color *= spotLightMapColor(slot, coord);
			}

			if (shadowed && directLight.visible && light_info.receive_shadow > 0.5) {
				directLight.color *= getSpotShadow(i, coord);
			}
		}

		RE_Direct(directLight, geometryPosition, geometryNormal, viewDir, material, reflectedLight);
	}

	for (int i = 0; i < MAX_DIRECTIONAL_LIGHTS; i++) {
		if (float(i) >= light_info.light_counts.x) {
			break;
		}

		getDirectionalLightInfo(i, directLight);

		if (float(i) < light_info.shadow_info.x && directLight.visible && light_info.receive_shadow > 0.5) {
			directLight.color *= getDirectionalShadow(i);
		}

		RE_Direct(directLight, geometryPosition, geometryNormal, viewDir, material, reflectedLight);
	}
}
#endif

// The indirect diffuse irradiance of lights_fragment_begin: ambient, light probes, hemisphere lights.
vec3 indirectIrradiance(vec3 geometryNormal) {
	vec3 irradiance = light_info.ambient_light_color;

	if (light_info.light_probes > 0.5) {
		irradiance += getLightProbeIrradiance(geometryNormal);
	}

	for (int i = 0; i < MAX_HEMI_LIGHTS; i++) {
		if (float(i) >= light_info.light_counts.w) {
			break;
		}

		irradiance += getHemisphereLightIrradiance(i, geometryNormal);
	}

	return irradiance;
}

#ifdef LIGHT_MATERIAL
// lights_fragment_maps for the materials without environment maps: the lightMap's irradiance.
vec3 lightMapIrradiance() {
#ifdef USE_LIGHTMAP
	return texture(light_map, v_light_map_uv).rgb * map_info.light_map_intensity;
#endif

	return vec3(0.0);
}
#endif
