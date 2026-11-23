#version 460 core

// A triangle covering the target, for the passes that fill a cube face or a mip level (lib/src/gpu/passes.dart):
// their fragment stages derive the direction of each texel from its position (shaders/face.glsl).
in vec2 position;

void main() {
	gl_Position = vec4(position, 0.0, 1.0);
}
