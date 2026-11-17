#version 460 core

// The depth half of a clear inside the frame's scissor (gl.clear is scissored; Flutter GPU's load action clears the
// whole attachment): the far depth, drawn with the color kept by blending. It samples a texture the blend discards:
// a fragment stage without one crashed flutter_tester, and one whose read the compiler removes crashes on Metal
// when the texture is bound (Flutter GPU 3.47.6, docs/flutter-gpu.md, Frame viewport).
uniform sampler2D source;

out vec4 frag_color;

void main() {
	frag_color = texture(source, vec2(0.5));
	gl_FragDepth = 1.0;
}
