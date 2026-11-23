#version 460 core

// SpriteMaterial's vertex stage (ShaderLib sprite): uv_vertex for the map and the alphaMap, the quad turned to
// face the camera (the view-space position of the object's origin, scaled by the object's world scale, by the
// view depth without USE_SIZEATTENUATION, shifted by center and rotated) and fog_vertex. Its VertInfo members are
// named as in shaders/mesh.vert, so the renderer writes both stages alike (members a stage lacks are skipped).
uniform VertInfo {
	mat4 projection_matrix;
	mat4 model_view_matrix;
	mat4 model_matrix;

	// The maps' uvTransforms, the upper-left 3×3 of a mat4.
	mat4 map_transform;
	mat4 alpha_map_transform;

	// rotation, center (x, y), USE_SIZEATTENUATION (1 or 0).
	vec4 sprite;
} vert_info;

in vec3 position;
in vec2 uv;

layout(location = 0) out vec3 v_view_position;
layout(location = 1) out vec2 v_map_uv;
layout(location = 2) out vec2 v_alpha_map_uv;

void main() {
	v_map_uv = (mat3(vert_info.map_transform) * vec3(uv, 1.0)).xy;
	v_alpha_map_uv = (mat3(vert_info.alpha_map_transform) * vec3(uv, 1.0)).xy;

	vec4 mv_position = vert_info.model_view_matrix[3];
	vec2 scale = vec2(length(vert_info.model_matrix[0].xyz), length(vert_info.model_matrix[1].xyz));

	// isPerspectiveMatrix: projectionMatrix[2][3] is -1.
	if (vert_info.sprite.w < 0.5 && vert_info.projection_matrix[2][3] == -1.0) {
		scale *= -mv_position.z;
	}

	vec2 aligned = (position.xy - (vert_info.sprite.yz - vec2(0.5))) * scale;
	float c = cos(vert_info.sprite.x);
	float s = sin(vert_info.sprite.x);
	mv_position.xy += vec2(c * aligned.x - s * aligned.y, s * aligned.x + c * aligned.y);

	v_view_position = -mv_position.xyz;
	gl_Position = vert_info.projection_matrix * mv_position;
}
