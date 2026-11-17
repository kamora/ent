#version 460 core

// The vertex stage of the effect materials (exception E-POSTPROCESSING): vUv = uv and the projected position, as in
// the reference's CopyShader, OutputShader and VignetteShader.
uniform VertInfo {
	mat4 projection_matrix;
	mat4 model_view_matrix;
} vert_info;

in vec3 position;
in vec2 uv;

layout(location = 0) out vec2 v_uv;

void main() {
	v_uv = uv;
	gl_Position = vert_info.projection_matrix * vert_info.model_view_matrix * vec4(position, 1.0);
}
