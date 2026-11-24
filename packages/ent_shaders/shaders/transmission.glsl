// transmission_pars_fragment and transmission_fragment (USE_TRANSMISSION, USE_DISPERSION): the opaque scene,
// rendered into a mipmapped target first (lib/src/gpu/transmission.dart), sampled along the refracted ray with
// mipped bicubic filtering (N8's), then attenuated by Beer's law. Based on the glTF Sample Viewer.
//
// Where 2D targets are drawn with their first row at the top (output_info.target_rows -1), WebGL's having it at the
// bottom, the projected v is mirrored before sampling. Include in shaders/physical.glsl after the BRDFs.
float w0(float a) {
	return (1.0 / 6.0) * (a * (a * (-a + 3.0) - 3.0) + 1.0);
}

float w1(float a) {
	return (1.0 / 6.0) * (a * a * (3.0 * a - 6.0) + 4.0);
}

float w2(float a) {
	return (1.0 / 6.0) * (a * (a * (-3.0 * a + 3.0) + 3.0) + 1.0);
}

float w3(float a) {
	return (1.0 / 6.0) * (a * a * a);
}

// The amplitude functions g0, g1 and the offset functions h0, h1.
float g0(float a) {
	return w0(a) + w1(a);
}

float g1(float a) {
	return w2(a) + w3(a);
}

float h0(float a) {
	return -1.0 + w1(a) / (w0(a) + w1(a));
}

float h1(float a) {
	return 1.0 + w3(a) / (w2(a) + w3(a));
}

vec4 bicubic(vec2 uv, vec4 texelSize, float lod) {
	uv = uv * texelSize.zw + 0.5;

	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);
	float g0x = g0(fuv.x);
	float g1x = g1(fuv.x);
	float h0x = h0(fuv.x);
	float h1x = h1(fuv.x);
	float h0y = h0(fuv.y);
	float h1y = h1(fuv.y);
	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) * texelSize.xy;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) * texelSize.xy;
	return g0(fuv.y) * (g0x * textureLod(transmission_sampler_map, p0, lod)
			+ g1x * textureLod(transmission_sampler_map, p1, lod))
		+ g1(fuv.y) * (g0x * textureLod(transmission_sampler_map, p2, lod)
			+ g1x * textureLod(transmission_sampler_map, p3, lod));
}

// textureSize at level [lod] of the target, as WebGL reports it (impellerc cannot translate textureSize).
vec2 levelSize(int lod) {
	return max(floor(frag_info.transmission_size / exp2(float(lod))), vec2(1.0));
}

vec4 textureBicubic(vec2 uv, float lod) {
	vec2 fLodSize = levelSize(int(lod));
	vec2 cLodSize = levelSize(int(lod + 1.0));
	vec2 fLodSizeInv = 1.0 / fLodSize;
	vec2 cLodSizeInv = 1.0 / cLodSize;
	vec4 fSample = bicubic(uv, vec4(fLodSizeInv, fLodSize), floor(lod));
	vec4 cSample = bicubic(uv, vec4(cLodSizeInv, cLodSize), ceil(lod));
	return mix(fSample, cSample, fract(lod));
}

vec3 getVolumeTransmissionRay(vec3 n, vec3 v, float thickness, float ior, mat4 modelMatrix) {

	// The direction of refracted light, scaled by the model's scale (the thickness is in local space).
	vec3 refractionVector = refract(-v, normalize(n), 1.0 / ior);
	vec3 modelScale;
	modelScale.x = length(vec3(modelMatrix[0].xyz));
	modelScale.y = length(vec3(modelMatrix[1].xyz));
	modelScale.z = length(vec3(modelMatrix[2].xyz));
	return normalize(refractionVector) * thickness * modelScale;
}

// An IOR of 1.0 refracts without microfacet roughness, 1.5 with the default amount.
float applyIorToRoughness(float roughness, float ior) {
	return roughness * clamp(ior * 2.0 - 2.0, 0.0, 1.0);
}

vec4 getTransmissionSample(vec2 fragCoord, float roughness, float ior) {
	float lod = log2(frag_info.transmission_size.x) * applyIorToRoughness(roughness, ior);
	return textureBicubic(vec2(fragCoord.x, output_info.target_rows < 0.0 ? 1.0 - fragCoord.y : fragCoord.y), lod);
}

vec3 volumeAttenuation(float transmissionDistance, vec3 attenuationColor, float attenuationDistance) {
	if (isinf(attenuationDistance)) {

		// An infinite attenuation distance does not attenuate.
		return vec3(1.0);
	}

	// Beer's law.
	vec3 attenuationCoefficient = -log(attenuationColor) / attenuationDistance;
	return exp(-attenuationCoefficient * transmissionDistance);
}

// The framebuffer coordinates [0, 1] the refracted ray leaves the volume at.
vec2 refractionCoords(vec3 position, vec3 ray, mat4 viewMatrix) {
	vec4 ndcPos = transmission_info.projection_matrix * viewMatrix * vec4(position + ray, 1.0);
	vec2 coords = ndcPos.xy / ndcPos.w;
	coords += 1.0;
	coords /= 2.0;
	return coords;
}

vec4 getIBLVolumeRefraction(vec3 n, vec3 v, float roughness, vec3 diffuseColor, vec3 specularColor, float specularF90,
		vec3 position, mat4 modelMatrix, mat4 viewMatrix, float dispersion, float ior, float thickness,
		vec3 attenuationColor, float attenuationDistance) {
	vec4 transmittedLight;
	vec3 transmittance;

	if (USE_DISPERSION) {
		float halfSpread = (ior - 1.0) * 0.025 * dispersion;
		vec3 iors = vec3(ior - halfSpread, ior, ior + halfSpread);
		transmittedLight = vec4(0.0);

		for (int i = 0; i < 3; i++) {
			vec3 transmissionRay = getVolumeTransmissionRay(n, v, thickness, iors[i], modelMatrix);
			vec4 transmissionSample = getTransmissionSample(refractionCoords(position, transmissionRay, viewMatrix),
				roughness, iors[i]);
			transmittedLight[i] = transmissionSample[i];
			transmittedLight.a += transmissionSample.a;
			transmittance[i] = diffuseColor[i]
				* volumeAttenuation(length(transmissionRay), attenuationColor, attenuationDistance)[i];
		}

		transmittedLight.a /= 3.0;
	} else {
		vec3 transmissionRay = getVolumeTransmissionRay(n, v, thickness, ior, modelMatrix);
		transmittedLight = getTransmissionSample(refractionCoords(position, transmissionRay, viewMatrix), roughness, ior);
		transmittance = diffuseColor * volumeAttenuation(length(transmissionRay), attenuationColor, attenuationDistance);
	}

	vec3 attenuatedColor = transmittance * transmittedLight.rgb;

	// The specular component; as less light is transmitted, opacity increases.
	vec3 F = EnvironmentBRDF(n, v, specularColor, specularF90, roughness);
	float transmittanceFactor = (transmittance.r + transmittance.g + transmittance.b) / 3.0;
	return vec4((1.0 - F) * attenuatedColor, 1.0 - (1.0 - transmittedLight.a) * transmittanceFactor);
}

// transmission_fragment: [totalDiffuse] mixed with the light transmitted through the volume; sets the material's
// transmission factors and transmissionAlpha.
vec3 transmit(inout PhysicalMaterial material, vec3 normal, vec3 totalDiffuse) {
	material.transmission = frag_info.transmission;
	material.transmissionAlpha = 1.0;
	material.thickness = frag_info.thickness;
	material.attenuationDistance = frag_info.attenuation_distance;
	material.attenuationColor = frag_info.attenuation_color;

	if (useMap(13)) {
		material.transmission *= texture(transmission_map, mapUv(13)).r;
	}

	if (useMap(14)) {
		material.thickness *= texture(thickness_map, mapUv(14)).g;
	}

	vec3 pos = v_world_position;
	vec3 v = normalize(env_info.camera_position - pos);
	vec3 n = transformNormalByInverseViewMatrix(normal, env_info.view_matrix);
	vec4 transmitted = getIBLVolumeRefraction(n, v, material.roughness, material.diffuseContribution,
		material.specularColorBlended, material.specularF90, pos, transmission_info.model_matrix, env_info.view_matrix,
		material.dispersion, material.ior, material.thickness, material.attenuationColor, material.attenuationDistance);

	material.transmissionAlpha = mix(material.transmissionAlpha, transmitted.a, material.transmission);
	return mix(totalDiffuse, transmitted.rgb, material.transmission);
}
