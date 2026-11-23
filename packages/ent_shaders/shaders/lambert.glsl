// MeshLambertMaterial's fragment stage (meshlambert.glsl): the shared maps, the shading normal, Lambert
// diffuse lighting (lights_lambert_pars_fragment) from the lights, the lightMap and a PMREM environment,
// ambient occlusion and emissive, a cube envMap (envmaps.glsl), then the common output (output.glsl).
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
} frag_info;

// specularStrength is read only by the cube envMap (envMapCombine), so the material leaves it out.
struct LambertMaterial {
	vec3 diffuseColor;
};

void RE_Direct(IncidentLight directLight, vec3 geometryPosition, vec3 geometryNormal, vec3 geometryViewDir,
		LambertMaterial material, inout ReflectedLight reflectedLight) {
	float dotNL = saturate(dot(geometryNormal, directLight.direction));
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert(material.diffuseColor);
}

#define LIGHT_MATERIAL LambertMaterial
#include "shaders/lights.glsl"

out vec4 frag_color;

void main() {
	vec4 diffuseColor = diffuseOf(vec4(frag_info.diffuse, frag_info.opacity));
	ReflectedLight reflectedLight = ReflectedLight(vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));
	vec3 normal = shadingNormal();
	vec3 totalEmissiveRadiance = emissiveOf(frag_info.emissive);

	LambertMaterial material;
	material.diffuseColor = diffuseColor.rgb;

	vec3 geometryPosition = -v_view_position;
	directLights(geometryPosition, normal, geometryViewDir(), material, reflectedLight);

	// RE_IndirectDiffuse_Lambert.
	vec3 irradiance = indirectIrradiance(normal) + lightMapIrradiance() + getIBLIrradiance(normal);
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert(material.diffuseColor);

	reflectedLight.indirectDiffuse *= ambientOcclusion();

	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	outgoingLight = envMapCombine(outgoingLight, normal, specularStrengthOf());

	frag_color = outputColor(outgoingLight, diffuseColor.a, v_view_position.z);
	applyPolygonOffset();
}
