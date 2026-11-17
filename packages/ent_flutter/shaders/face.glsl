// The cube face a pass renders into and the direction through the centre of the texel being shaded, as the GL
// cube map table maps a face and (s, t) to a direction (Metal and WebGL agree on it; t is 0 at the first row).
//
// The reference renders a BoxGeometry(5, 5, 5) with a CubeCamera (fov 90) and interpolates the normalized box
// corners (cube_vert): every corner has the same length, so the interpolated vector points through the
// texel centre; this computes that direction directly. A render target's first row is at the top here and at
// the bottom in WebGL, which the table's t already accounts for: both store row 0 at t = 0.
uniform FaceInfo {

	// The face: 0 +X, 1 -X, 2 +Y, 3 -Y, 4 +Z, 5 -Z.
	float face;

	// The face size in texels at the level being rendered.
	float size;
} face_info;

vec3 faceDirection() {
	vec2 st = gl_FragCoord.xy / face_info.size * 2.0 - 1.0;
	float sc = st.x;
	float tc = st.y;
	int face = int(face_info.face + 0.5);

	if (face == 0) {
		return vec3(1.0, -tc, -sc);
	} else if (face == 1) {
		return vec3(-1.0, -tc, sc);
	} else if (face == 2) {
		return vec3(sc, 1.0, tc);
	} else if (face == 3) {
		return vec3(sc, -1.0, -tc);
	} else if (face == 4) {
		return vec3(sc, -tc, 1.0);
	}

	return vec3(-sc, -tc, -1.0);
}
