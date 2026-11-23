#version 460 core

// PointsMaterial's vertex stage (points.glsl): color_vertex, project_vertex, the point size with
// USE_SIZEATTENUATION, USE_POINTS_UV and fog_vertex. Its VertInfo members are named as in shaders/mesh.vert, so
// the renderer writes both stages alike (members a stage lacks are skipped).
uniform VertInfo {
	mat4 projection_matrix;
	mat4 model_view_matrix;

	// uvTransform (USE_POINTS_UV), the upper-left 3×3 of a mat4.
	mat4 map_transform;

	// size (× pixel ratio), scale (height / 2), USE_SIZEATTENUATION (1 or 0).
	vec3 point;
} vert_info;

in vec3 position;
in vec2 uv;
in vec4 color;

layout(location = 0) out vec3 v_view_position;
layout(location = 1) out vec2 v_uv;
layout(location = 2) out vec4 v_color;

void main() {
	v_uv = (mat3(vert_info.map_transform) * vec3(uv, 1.0)).xy;

	// A vec3 color is uploaded with alpha 1, so USE_COLOR and USE_COLOR_ALPHA are the same product.
	v_color = color;

	vec4 mv_position = vert_info.model_view_matrix * vec4(position, 1.0);
	v_view_position = -mv_position.xyz;
	gl_Position = vert_info.projection_matrix * mv_position;
	gl_PointSize = vert_info.point.x;

	// isPerspectiveMatrix: projectionMatrix[2][3] is -1.
	if (vert_info.point.z > 0.5 && vert_info.projection_matrix[2][3] == -1.0) {
		gl_PointSize *= vert_info.point.y / -mv_position.z;
	}
}
