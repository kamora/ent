// ShadowMaterial's fragment stage (shadow.glsl): the material's color with opacity × (1 − getShadowMask()), the
// shadows of the shadow-casting directional, spot and point lights this object receives
// (shadowmask_pars_fragment), then the common output (output.glsl). No maps; lights.glsl is included without
// LIGHT_MATERIAL, for its uniforms and shadow lookups only.
#include "shaders/output.glsl"
#include "shaders/common.glsl"
#include "shaders/mesh_in.glsl"
#include "shaders/lights.glsl"

uniform FragInfo {
	vec3 color;
	float opacity;
} frag_info;

out vec4 frag_color;

// getShadowMask of shadowmask_pars_fragment: the product of every shadow-casting light's shadow, whether or not the
// light reaches the fragment; 1 when the object does not receive shadows.
float getShadowMask() {
	float shadow = 1.0;

	if (light_info.receive_shadow < 0.5) {
		return shadow;
	}

	for (int i = 0; i < MAX_DIRECTIONAL_LIGHTS; i++) {
		if (float(i) >= light_info.shadow_info.x) {
			break;
		}

		shadow *= getDirectionalShadow(i);
	}

	for (int i = 0; i < MAX_SPOT_LIGHTS; i++) {
		if (float(i) >= light_info.spot_shadows) {
			break;
		}

		shadow *= getSpotShadow(i, spotLightCoord(i, true));
	}

	for (int i = 0; i < MAX_POINT_LIGHTS; i++) {
		if (float(i) >= light_info.point_shadows) {
			break;
		}

		shadow *= getPointShadow(i);
	}

	return shadow;
}

void main() {
	frag_color = finishColor(vec4(frag_info.color, frag_info.opacity * (1.0 - getShadowMask())), v_view_position.z);
	applyPolygonOffset();
}
