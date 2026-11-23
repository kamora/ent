// MeshBasicMaterial's fragment stage (meshbasic.glsl): map, vertex colors, alphaMap, alphaTest, the baked
// indirect light of a lightMap, ambient occlusion, a cube envMap (envmaps.glsl, scaled by the specularMap),
// then the common output (output.glsl). An sRGB map is sampled from an sRGB texture format that decodes in
// hardware, as WebGL's SRGB8_ALPHA8 does. With DASHED (shaders/dashed.glsl), LineDashedMaterial's stage
// (linedashed.glsl): the same color, map, vertex colors and fog, with gaps discarded.
#include "shaders/output.glsl"
#include "shaders/common.glsl"
#include "shaders/mesh_in.glsl"
#include "shaders/maps.glsl"
#include "shaders/envmaps.glsl"

uniform FragInfo {
	vec3 diffuse;
	float opacity;
	mat4 line_projection;
	vec4 line;
#ifdef DASHED
	float dash_size;
	float total_size;
#endif
} frag_info;

out vec4 frag_color;

void main() {

	// Lines (line.z 1): WebGL on ANGLE keeps a line's fragment only where the line passes through the pixel's
	// diamond (GL's diamond-exit rule, ANGLE's Bresenham line emulation); line.xy is the target's size.
	if (frag_info.line.z > 0.5) {
		vec4 clip = frag_info.line_projection * vec4(-v_view_position, 1.0);
		vec2 ba = abs((clip.xy / clip.w * vec2(0.5, -0.5) + 0.5) * frag_info.line.xy - gl_FragCoord.xy);
		vec2 ba2 = 2.0 * ba * ba;
		vec2 bp = ba2 + ba2.yx - ba;

		if (bp.x > 1e-5 && bp.y > 1e-5) {
			discard;
		}
	}

#ifdef DASHED
	if (mod(v_line_distance, frag_info.total_size) > frag_info.dash_size) {
		discard;
	}
#endif

	vec4 diffuseColor = diffuseOf(vec4(frag_info.diffuse, frag_info.opacity));

	// Accumulation (baked indirect lighting only): without a lightMap the indirect diffuse light is 1.
	vec3 indirectDiffuse = vec3(1.0);

#ifdef USE_LIGHTMAP
	indirectDiffuse = texture(light_map, v_light_map_uv).rgb * map_info.light_map_intensity * RECIPROCAL_PI;
#endif

	indirectDiffuse *= ambientOcclusion();
	indirectDiffuse *= diffuseColor.rgb;

	vec3 outgoingLight = envMapCombine(indirectDiffuse, normalize(v_normal), specularStrengthOf());

	frag_color = outputColor(outgoingLight, diffuseColor.a, v_view_position.z);
	applyPolygonOffset();
}
