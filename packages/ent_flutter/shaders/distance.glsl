// MeshDistanceMaterial's fragment stage (distance.glsl): the world-space distance to the reference position (a
// point light's position, set while rendering its shadow map), mapped from [near, far] to [0, 1] in red. No
// tone mapping, color space conversion or fog; only the polygon offset (offset.glsl).
#include "shaders/offset.glsl"
#include "shaders/mesh_in.glsl"
#include "shaders/maps.glsl"

uniform FragInfo {
	vec3 reference_position;
	float near_distance;
	float far_distance;
} frag_info;

out vec4 frag_color;

void main() {
	diffuseOf(vec4(1.0));

	float dist = length(v_world_position - frag_info.reference_position);
	dist = (dist - frag_info.near_distance) / (frag_info.far_distance - frag_info.near_distance);
	dist = saturate(dist);

	frag_color = vec4(dist, 0.0, 0.0, 1.0);
	applyPolygonOffset();
}
