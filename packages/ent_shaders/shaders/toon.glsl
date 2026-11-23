// MeshToonMaterial's fragment stage (meshtoon.glsl): as Lambert, with the direct irradiance read from the
// gradientMap (gradientmap_pars_fragment; a default two-step ramp without one).
#include "shaders/output.glsl"
#include "shaders/common.glsl"
#include "shaders/mesh_in.glsl"
#include "shaders/maps.glsl"
#include "shaders/normals.glsl"

uniform FragInfo {
	vec3 diffuse;
	float opacity;

	// emissive × emissiveIntensity.
	vec3 emissive;
} frag_info;

#ifdef USE_GRADIENTMAP
uniform sampler2D gradient_map;
#endif

vec3 getGradientIrradiance(vec3 normal, vec3 lightDirection) {
	float dotNL = dot(normal, lightDirection);
	vec2 coord = vec2(dotNL * 0.5 + 0.5, 0.0);

#ifdef USE_GRADIENTMAP
	return vec3(texture(gradient_map, coord).r);
#endif

	vec2 fw = fwidth(coord) * 0.5;
	return mix(vec3(0.7), vec3(1.0), smoothstep(0.7 - fw.x, 0.7 + fw.x, coord.x));
}

struct ToonMaterial {
	vec3 diffuseColor;
};

void RE_Direct(IncidentLight directLight, vec3 geometryPosition, vec3 geometryNormal, vec3 geometryViewDir,
		ToonMaterial material, inout ReflectedLight reflectedLight) {
	vec3 irradiance = getGradientIrradiance(geometryNormal, directLight.direction) * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert(material.diffuseColor);
}

#define LIGHT_MATERIAL ToonMaterial
#include "shaders/lights.glsl"

out vec4 frag_color;

void main() {
	vec4 diffuseColor = diffuseOf(vec4(frag_info.diffuse, frag_info.opacity));
	ReflectedLight reflectedLight = ReflectedLight(vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));
	vec3 normal = shadingNormal();
	vec3 totalEmissiveRadiance = emissiveOf(frag_info.emissive);

	ToonMaterial material;
	material.diffuseColor = diffuseColor.rgb;

	vec3 geometryPosition = -v_view_position;
	directLights(geometryPosition, normal, geometryViewDir(), material, reflectedLight);

	// RE_IndirectDiffuse_Toon.
	vec3 irradiance = indirectIrradiance(normal) + lightMapIrradiance();
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert(material.diffuseColor);

	reflectedLight.indirectDiffuse *= ambientOcclusion();

	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;

	frag_color = outputColor(outgoingLight, diffuseColor.a, v_view_position.z);
	applyPolygonOffset();
}
