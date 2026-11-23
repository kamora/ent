#version 460 core

// The reference's background plane for a texture background (ShaderLib.background): a 2 × 2 plane covering the
// frame at the far plane, its uv transformed by the texture's matrix.
uniform VertInfo {

	// The texture's uv transform (mat3 as the upper-left of a mat4).
	mat4 uv_transform;
} vert_info;

in vec3 position;
in vec2 uv;

layout(location = 0) out vec2 v_uv;

void main() {
	v_uv = (mat3(vert_info.uv_transform) * vec3(uv, 1.0)).xy;
	gl_Position = vec4(position.xy, 1.0, 1.0);
}
