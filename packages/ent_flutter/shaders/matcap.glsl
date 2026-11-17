// MeshMatcapMaterial's fragment stage (meshmatcap.glsl): the diffuse color times the matcap texel the view-space
// normal points at (a default gray ramp without a matcap), then the common output (output.glsl).
#include "shaders/output.glsl"
#include "shaders/mesh_in.glsl"
#include "shaders/maps.glsl"
#include "shaders/normals.glsl"

uniform FragInfo {
	vec3 diffuse;
	float opacity;
} frag_info;

#ifdef USE_MATCAP
uniform sampler2D matcap;
#endif

out vec4 frag_color;

void main() {
	vec4 diffuseColor = diffuseOf(vec4(frag_info.diffuse, frag_info.opacity));
	vec3 normal = shadingNormal();

	vec3 viewDir = normalize(v_view_position);
	vec3 x = normalize(vec3(viewDir.z, 0.0, -viewDir.x));
	vec3 y = cross(viewDir, x);

	// 0.495 removes artifacts caused by undersized matcap disks.
	vec2 uv = vec2(dot(x, normal), dot(y, normal)) * 0.495 + 0.5;
	vec4 matcapColor = vec4(vec3(mix(0.2, 0.8, uv.y)), 1.0);

#ifdef USE_MATCAP
	matcapColor = texture(matcap, uv);
#endif

	vec3 outgoingLight = diffuseColor.rgb * matcapColor.rgb;

	frag_color = outputColor(outgoingLight, diffuseColor.a, v_view_position.z);
	applyPolygonOffset();
}
