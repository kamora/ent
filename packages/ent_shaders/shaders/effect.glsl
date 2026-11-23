// What the registered effect fragment stages share (exception E-POSTPROCESSING): vUv from shaders/effect.vert
// and the coordinate tDiffuse is read at.
layout(location = 0) in vec2 v_uv;

out vec4 frag_color;

// A render target's rows start at the top here, at the bottom in WebGL: with [flip] (tDiffuse is a render
// target's texture) t is flipped (t' = 1 - t).
vec2 effectUv(vec2 uv, float flip) {
	return vec2(uv.x, flip > 0.5 ? 1.0 - uv.y : uv.y);
}
