// SpriteMaterial's fragment stage (ShaderLib sprite): map_fragment, alphamap_fragment, alphatest_fragment, then
// the common output (output.glsl) with fog. A variant defines USE_MAP and USE_ALPHAMAP for the maps it uses.
#include "shaders/output.glsl"

uniform FragInfo {
	vec3 diffuse;
	float opacity;

	// USE_ALPHATEST when above 0.
	float alpha_test;
} frag_info;

#ifdef USE_MAP
uniform sampler2D map;
#endif

#ifdef USE_ALPHAMAP
uniform sampler2D alpha_map;
#endif

layout(location = 0) in vec3 v_view_position;
layout(location = 1) in vec2 v_map_uv;
layout(location = 2) in vec2 v_alpha_map_uv;

out vec4 frag_color;

void main() {
	vec4 diffuseColor = vec4(frag_info.diffuse, frag_info.opacity);

#ifdef USE_MAP
	diffuseColor *= texture(map, v_map_uv);
#endif

#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture(alpha_map, v_alpha_map_uv).g;
#endif

	if (frag_info.alpha_test > 0.0 && diffuseColor.a < frag_info.alpha_test) {
		discard;
	}

	frag_color = outputColor(diffuseColor.rgb, diffuseColor.a, v_view_position.z);
	applyPolygonOffset();
}
