// The reference's environment map chunks: envmap_common_pars_fragment, envmap_pars_fragment, envmap_fragment (cube maps
// combined with the outgoing light, for MeshBasicMaterial, MeshLambertMaterial and MeshPhongMaterial) and
// envmap_physical_pars_fragment (image-based lighting from a PMREM, for MeshStandardMaterial,
// MeshPhysicalMaterial and the PMREM irradiance of Lambert and Phong). The PMREM is a cube texture whose mip
// levels hold the prefiltered radiance (PMREMGenerator, lib/src/gpu/environments.dart), so both kinds
// sample one samplerCube. Include after shaders/common.glsl and shaders/mesh_in.glsl.
uniform EnvInfo {

	// envMapRotation, transposed and mirrored in x for a cube texture that is not a render target, as
	// the reference writes it (mat3 as the upper-left of a mat4).
	mat4 env_rotation;

	// The camera's matrixWorldInverse (viewMatrix) and position (cameraPosition).
	mat4 view_matrix;
	vec3 camera_position;

	// 0: no envMap, 1: ENVMAP_TYPE_CUBE, 2: ENVMAP_TYPE_PMREM.
	float env_type;
	float env_intensity;

	// ENVMAP_MAX_LOD: the PMREM's last mip level.
	float env_max_lod;
	float reflectivity;
	float refraction_ratio;

	// 1 for ENVMAP_MODE_REFRACTION, 0 for ENVMAP_MODE_REFLECTION.
	float env_refraction;

	// ENVMAP_BLENDING_MULTIPLY (0), _MIX (1), _ADD (2): the material's combine.
	float combine;

	// ENV_WORLDPOS: the reflection is computed here from the world position (Lambert, Phong), else the vertex
	// stage's vReflect is used (MeshBasicMaterial).
	float world_position;
	float is_orthographic;
} env_info;

#ifndef TEXTURE_SLOTS
uniform samplerCube env_map;
#endif

vec3 transformNormalByInverseViewMatrix(vec3 normal, mat4 viewMatrix) {
	return normalize((vec4(normal, 0.0) * viewMatrix).xyz);
}

vec3 transformDirectionByInverseViewMatrix(vec3 dir, mat4 viewMatrix) {
	return normalize((vec4(dir, 0.0) * viewMatrix).xyz);
}

// The inverse of PMREMGenerator.lodToRoughness (Filament's perceptualRoughnessToLod).
float roughnessToMip(float roughness) {
	float r = clamp(roughness, 0.0, 1.0);
	return env_info.env_max_lod * r * (2.0 - r);
}

vec3 getIBLIrradiance(vec3 normal) {
	if (env_info.env_type < 1.5) {
		return vec3(0.0);
	}

	vec3 worldNormal = transformNormalByInverseViewMatrix(normal, env_info.view_matrix);
	vec4 envMapColor = textureLod(env_map, mat3(env_info.env_rotation) * worldNormal, env_info.env_max_lod);
	return PI * envMapColor.rgb * env_info.env_intensity;
}

vec3 getIBLRadiance(vec3 viewDir, vec3 normal, float roughness) {
	if (env_info.env_type < 1.5) {
		return vec3(0.0);
	}

	vec3 reflectVec = reflect(-viewDir, normal);

	// Mixing the reflection with the normal keeps rough objects from gathering light from behind their
	// tangent plane.
	reflectVec = normalize(mix(reflectVec, normal, pow4(roughness)));
	reflectVec = transformDirectionByInverseViewMatrix(reflectVec, env_info.view_matrix);

	vec4 envMapColor = textureLod(env_map, mat3(env_info.env_rotation) * reflectVec, roughnessToMip(roughness));
	return envMapColor.rgb * env_info.env_intensity;
}

// The retroreflective lobe returns light toward its source, so it samples along the view direction.
vec3 getIBLRetroRadiance(vec3 viewDir, vec3 normal, float roughness) {
	if (env_info.env_type < 1.5) {
		return vec3(0.0);
	}

	vec3 retroVec = normalize(mix(viewDir, normal, pow4(roughness)));
	retroVec = transformDirectionByInverseViewMatrix(retroVec, env_info.view_matrix);

	vec4 envMapColor = textureLod(env_map, mat3(env_info.env_rotation) * retroVec, roughnessToMip(roughness));
	return envMapColor.rgb * env_info.env_intensity;
}

// Filament's bent normal for anisotropic image-based lighting.
vec3 anisotropyBentNormal(vec3 viewDir, vec3 normal, float roughness, vec3 bitangent, float anisotropy) {
	vec3 bentNormal = cross(bitangent, viewDir);
	bentNormal = normalize(cross(bentNormal, bitangent));
	return normalize(mix(bentNormal, normal, pow2(pow2(1.0 - anisotropy * (1.0 - roughness)))));
}

// envmap_fragment for ENVMAP_TYPE_CUBE: the cube map's color along the reflected (or refracted) view ray,
// combined with [outgoingLight] by the material's combine operation.
vec3 envMapCombine(vec3 outgoingLight, vec3 normal, float specularStrength) {
	if (env_info.env_type < 0.5 || env_info.env_type > 1.5) {
		return outgoingLight;
	}

	vec3 reflectVec;

	if (env_info.world_position > 0.5) {
		mat4 view = env_info.view_matrix;
		vec3 cameraToFrag = env_info.is_orthographic > 0.5
			? normalize(vec3(-view[0][2], -view[1][2], -view[2][2]))
			: normalize(v_world_position - env_info.camera_position);
		vec3 worldNormal = transformNormalByInverseViewMatrix(normal, view);

		reflectVec = env_info.env_refraction > 0.5
			? refract(cameraToFrag, worldNormal, env_info.refraction_ratio)
			: reflect(cameraToFrag, worldNormal);
	} else {
		reflectVec = v_reflect;
	}

	vec4 envColor = texture(env_map, mat3(env_info.env_rotation) * reflectVec);
	float amount = specularStrength * env_info.reflectivity;

	if (env_info.combine < 0.5) {
		return mix(outgoingLight, outgoingLight * envColor.xyz, amount);
	} else if (env_info.combine < 1.5) {
		return mix(outgoingLight, envColor.xyz, amount);
	} else if (env_info.combine < 2.5) {
		return outgoingLight + envColor.xyz * amount;
	}

	return outgoingLight;
}
