// MeshNormalMaterial's fragment stage (meshnormal.glsl): packNormalToRGB of the view-space shading normal
// (normals.glsl: smooth or flat, flipped for back faces of double-sided materials, normal and bump maps).
// The reference applies no tone mapping, color space conversion or fog here; only OPAQUE and the polygon offset
// come from output.glsl.
#include "shaders/output.glsl"
#include "shaders/mesh_in.glsl"
#include "shaders/normals.glsl"

uniform FragInfo {
	float opacity;
} frag_info;

out vec4 frag_color;

void main() {

	// Never taken. On Metal (Apple M1) a fragment stage that cannot discard gets 2 × 2 quads that mix two triangles:
	// dFdx and dFdy of a flat-shaded sphere blended neighbouring facets at their seams. One that may discard does not
	// (measured; the lit stages discard on alphaTest in maps.glsl).
	if (normal_info.flat_shaded < 0.0) {
		discard;
	}

	frag_color = vec4(normalize(shadingNormal()) * 0.5 + 0.5, output_info.opaque > 0.5 ? 1.0 : frag_info.opacity);
	applyPolygonOffset();
}
