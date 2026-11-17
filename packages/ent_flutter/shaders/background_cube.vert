#version 460 core

// The reference's background box for a cube background (ShaderLib.backgroundCube): a unit box around the camera whose
// world directions reach the fragment stage, drawn at the far plane.
uniform VertInfo {
	mat4 projection_matrix;
	mat4 model_view_matrix;
	mat4 model_matrix;
} vert_info;

in vec3 position;

layout(location = 0) out vec3 v_world_direction;

void main() {
	v_world_direction = normalize((vert_info.model_matrix * vec4(position, 0.0)).xyz);
	gl_Position = vert_info.projection_matrix * (vert_info.model_view_matrix * vec4(position, 1.0));

	// At camera.far.
	gl_Position.z = gl_Position.w;
}
