#version 460 core

// The start of a render into the frame that keeps its color (exception E-FRAME): the previous render's texture,
// or transparent black without one, and the clear value inside `rect` (x0, y0, x1, y1 from the top left; empty
// without a clear inside the frame's scissor, as gl.clear is scissored).
uniform FrameInfo {
	// The frame's size in pixels.
	vec2 size;

	// 1 when `previous` is the previous render's texture, 0 for transparent black.
	float copy;

	vec4 rect;

	// The clear value, premultiplied.
	vec4 color;
} frame_info;

uniform sampler2D previous;

out vec4 frag_color;

void main() {
	vec2 p = gl_FragCoord.xy;

	if (all(greaterThanEqual(p, frame_info.rect.xy)) && all(lessThan(p, frame_info.rect.zw))) {
		frag_color = frame_info.color;
	} else {
		frag_color = frame_info.copy * textureLod(previous, p / frame_info.size, 0.0);
	}
}
