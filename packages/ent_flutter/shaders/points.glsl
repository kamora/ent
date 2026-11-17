// PointsMaterial's fragment stage (points.glsl): map_particle_fragment (the map and alphaMap at gl_PointCoord
// through uvTransform, or at the uv attribute with USE_POINTS_UV), vertex colors (white without vertexColors),
// alphaTest, then the common output (output.glsl). A variant defines USE_MAP and USE_ALPHAMAP for the maps it uses.
#include "shaders/output.glsl"

uniform FragInfo {
	vec3 diffuse;
	float opacity;
	mat4 uv_transform;

	// USE_POINTS_UV (the geometry has uvs): 1 or 0.
	float points_uv;

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
layout(location = 1) in vec2 v_uv;
layout(location = 2) in vec4 v_color;

out vec4 frag_color;

void main() {
	vec4 diffuseColor = vec4(frag_info.diffuse, frag_info.opacity);

#if defined(USE_MAP) || defined(USE_ALPHAMAP)
	vec2 uv = frag_info.points_uv > 0.5
		? v_uv
		: (mat3(frag_info.uv_transform) * vec3(gl_PointCoord.x, 1.0 - gl_PointCoord.y, 1.0)).xy;
#endif

#ifdef USE_MAP
	diffuseColor *= texture(map, uv);
#endif

#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture(alpha_map, uv).g;
#endif

	diffuseColor *= v_color;

	if (frag_info.alpha_test > 0.0 && diffuseColor.a < frag_info.alpha_test) {
		discard;
	}

	frag_color = outputColor(diffuseColor.rgb, diffuseColor.a, v_view_position.z);
	applyPolygonOffset();
}
