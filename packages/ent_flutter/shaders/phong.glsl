// MeshPhongMaterial's fragment stage (meshphong.glsl): as Lambert, plus Blinn-Phong specular
// (lights_phong_pars_fragment) scaled by the specularMap.
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

	// max(shininess, 1e-4), as refreshUniformsPhong.
	float shininess;
	vec3 specular;
} frag_info;

struct BlinnPhongMaterial {
	vec3 diffuseColor;
	vec3 specularColor;
	float specularShininess;
	float specularStrength;
};

// bsdfs: G_BlinnPhong_Implicit is 0.25.
float D_BlinnPhong(float shininess, float dotNH) {
	return RECIPROCAL_PI * (shininess * 0.5 + 1.0) * pow(dotNH, shininess);
}

vec3 BRDF_BlinnPhong(vec3 lightDir, vec3 viewDir, vec3 normal, vec3 specularColor, float shininess) {
	vec3 halfDir = normalize(lightDir + viewDir);
	float dotNH = saturate(dot(normal, halfDir));
	float dotVH = saturate(dot(viewDir, halfDir));
	vec3 F = F_Schlick(specularColor, 1.0, dotVH);
	float G = 0.25;
	float D = D_BlinnPhong(shininess, dotNH);
	return F * (G * D);
}

void RE_Direct(IncidentLight directLight, vec3 geometryPosition, vec3 geometryNormal, vec3 geometryViewDir,
		BlinnPhongMaterial material, inout ReflectedLight reflectedLight) {
	float dotNL = saturate(dot(geometryNormal, directLight.direction));
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert(material.diffuseColor);
	reflectedLight.directSpecular += irradiance * BRDF_BlinnPhong(directLight.direction, geometryViewDir, geometryNormal,
		material.specularColor, material.specularShininess) * material.specularStrength;
}

#define LIGHT_MATERIAL BlinnPhongMaterial
#include "shaders/lights.glsl"

out vec4 frag_color;

void main() {
	vec4 diffuseColor = diffuseOf(vec4(frag_info.diffuse, frag_info.opacity));
	ReflectedLight reflectedLight = ReflectedLight(vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));
	float specularStrength = specularStrengthOf();
	vec3 normal = shadingNormal();
	vec3 totalEmissiveRadiance = emissiveOf(frag_info.emissive);

	BlinnPhongMaterial material;
	material.diffuseColor = diffuseColor.rgb;
	material.specularColor = frag_info.specular;
	material.specularShininess = frag_info.shininess;
	material.specularStrength = specularStrength;

	vec3 geometryPosition = -v_view_position;
	directLights(geometryPosition, normal, geometryViewDir(), material, reflectedLight);

	// RE_IndirectDiffuse_BlinnPhong.
	vec3 irradiance = indirectIrradiance(normal) + lightMapIrradiance() + getIBLIrradiance(normal);
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert(material.diffuseColor);

	reflectedLight.indirectDiffuse *= ambientOcclusion();

	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse
		+ reflectedLight.directSpecular + reflectedLight.indirectSpecular + totalEmissiveRadiance;
	outgoingLight = envMapCombine(outgoingLight, normal, specularStrength);

	frag_color = outputColor(outgoingLight, diffuseColor.a, v_view_position.z);
	applyPolygonOffset();
}
