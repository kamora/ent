// The polygon offset WebGL applies in fixed function, for the *_offset variants (POLYGON_OFFSET defined), and
// saturate(). Every fragment stage includes it.
//
// A uniform block a stage declares but never reads must not exist: impellerc removes it from the compiled
// shader while the reflection still lists it, so binding it moves the other blocks to the wrong buffers
// (Flutter 3.47.6). OffsetInfo is therefore declared only in the variants that read it.
#define saturate(a) clamp(a, 0.0, 1.0)

#ifdef POLYGON_OFFSET
uniform OffsetInfo {

	// polygonOffsetFactor and polygonOffsetUnits.
	vec2 polygon_offset;
} offset_info;
#endif

// glPolygonOffset( factor, units ) for a 32-bit float depth buffer: the depth slope of the triangle times
// factor, plus units times the depth resolution at this depth (2^(exponent - 23)). Flutter GPU has no depth
// bias state, so the *_offset fragment variants write it as the fragment depth.
void applyPolygonOffset() {
#ifdef POLYGON_OFFSET
	float z = gl_FragCoord.z;
	gl_FragDepth = z
		+ offset_info.polygon_offset.x * max(abs(dFdx(z)), abs(dFdy(z)))
		+ offset_info.polygon_offset.y * exp2(floor(log2(max(z, 1e-30))) - 23.0);
#endif
}
