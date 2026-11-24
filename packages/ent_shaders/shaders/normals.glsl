// The shading normal of the reference's normal_fragment_begin and normal_fragment_maps: smooth or flat (FLAT_SHADED),
// flipped on back faces of double-sided materials, then perturbed by a tangent-space or object-space
// normalMap (with geometry tangents or derivatives, getTangentFrame) or by a bumpMap (perturbNormalArb).
//
// Window y points down where rows run down (output_info.rows -1) and up in WebGL, so dFdy has the opposite sign
// there; dFdyGL gives WebGL's.
#define dFdyGL(a) (output_info.rows * dFdy(a))

// A variant defines the normal map flag it uses: USE_NORMALMAP_TANGENTSPACE, USE_NORMALMAP_OBJECTSPACE or
// USE_BUMPMAP.
uniform NormalInfo {

	// The object's normalMatrix, for object-space normal maps (mat3 as the upper-left of a mat4).
	mat4 normal_matrix;
	vec2 normal_scale;
	float bump_scale;

	// DOUBLE_SIDED, FLAT_SHADED, FLIP_SIDED, USE_TANGENT: 1 or 0.
	float double_sided;
	float flat_shaded;
	float flip_sided;
	float use_tangent;
} normal_info;

// A stage that reads its textures through slots (slots.glsl) declares none of these samplers by name.
#ifndef TEXTURE_SLOTS
#if defined(USE_NORMALMAP_TANGENTSPACE) || defined(USE_NORMALMAP_OBJECTSPACE)
uniform sampler2D normal_map;
#endif

#ifdef USE_BUMPMAP
uniform sampler2D bump_map;
#endif
#endif

// Normal mapping without precomputed tangents (http://www.thetenthplanet.de/archives/1180).
mat3 getTangentFrame(vec3 eye_pos, vec3 surf_norm, vec2 uv) {
	vec3 q0 = dFdx(eye_pos.xyz);
	vec3 q1 = dFdyGL(eye_pos.xyz);
	vec2 st0 = dFdx(uv.st);
	vec2 st1 = dFdyGL(uv.st);
	vec3 N = surf_norm;
	vec3 q1perp = cross(q1, N);
	vec3 q0perp = cross(N, q0);
	vec3 T = q1perp * st0.x + q0perp * st1.x;
	vec3 B = q1perp * st0.y + q0perp * st1.y;
	float det = max(dot(T, T), dot(B, B));
	float scale = (det == 0.0) ? 0.0 : inversesqrt(det);
	return mat3(T * scale, B * scale, N);
}

#ifdef USE_BUMPMAP

// Bump mapping unparametrized surfaces on the GPU (Mikkelsen), forward differencing.
vec2 dHdxy_fwd() {
#ifdef TEXTURE_SLOTS

	// readSlots (physical.glsl) read the three texels.
	float Hll = normal_info.bump_scale * slot_reads[READ_BUMP_MAP].x;
	float dBx = normal_info.bump_scale * slot_reads[READ_BUMP_MAP_DX].x - Hll;
	float dBy = normal_info.bump_scale * slot_reads[READ_BUMP_MAP_DY].x - Hll;
#else
	vec2 dSTdx = dFdx(v_bump_map_uv);
	vec2 dSTdy = dFdyGL(v_bump_map_uv);
	float Hll = normal_info.bump_scale * texture(bump_map, v_bump_map_uv).x;
	float dBx = normal_info.bump_scale * texture(bump_map, v_bump_map_uv + dSTdx).x - Hll;
	float dBy = normal_info.bump_scale * texture(bump_map, v_bump_map_uv + dSTdy).x - Hll;
#endif
	return vec2(dBx, dBy);
}
#endif

vec3 perturbNormalArb(vec3 surf_pos, vec3 surf_norm, vec2 dHdxy, float faceDirection) {
	vec3 vSigmaX = normalize(dFdx(surf_pos.xyz));
	vec3 vSigmaY = normalize(dFdyGL(surf_pos.xyz));
	vec3 vN = surf_norm;
	vec3 R1 = cross(vSigmaY, vN);
	vec3 R2 = cross(vN, vSigmaX);
	float fDet = dot(vSigmaX, R1) * faceDirection;
	vec3 vGrad = sign(fDet) * (dHdxy.x * R1 + dHdxy.y * R2);
	return normalize(abs(fDet) * surf_norm - vGrad);
}

// The normal of normal_fragment_begin: flat (FLAT_SHADED) or the interpolated one, flipped on back faces of
// double-sided materials.
vec3 beginNormal(float faceDirection) {
	if (normal_info.flat_shaded > 0.5) {
		return normalize(cross(dFdx(v_view_position), dFdyGL(v_view_position)));
	}

	vec3 normal = normalize(v_normal);

	if (normal_info.double_sided > 0.5) {
		normal *= faceDirection;
	}

	return normal;
}

// The tangent frame of normal_fragment_begin: from geometry tangents (USE_TANGENT) or derivatives of [uv].
mat3 tangentFrame(vec3 normal, vec2 uv, float faceDirection) {
	mat3 tbn;

	if (normal_info.use_tangent > 0.5) {
		tbn = mat3(normalize(v_tangent), normalize(v_bitangent), normal);
	} else {
		tbn = getTangentFrame(-v_view_position, normal, uv);
	}

	if (normal_info.double_sided > 0.5) {
		tbn[0] *= faceDirection;
		tbn[1] *= faceDirection;
	}

	return tbn;
}

// normal_fragment_maps: [normal] perturbed by the normalMap (object space, or tangent space with [tbn]) or the
// bumpMap.
vec3 mapNormal(vec3 normal, mat3 tbn, float faceDirection) {
#ifdef USE_NORMALMAP_OBJECTSPACE

	// Overrides both flatShading and attribute normals.
	normal = texture(normal_map, v_normal_map_uv).xyz * 2.0 - 1.0;

	if (normal_info.flip_sided > 0.5) {
		normal = -normal;
	}

	if (normal_info.double_sided > 0.5) {
		normal = normal * faceDirection;
	}

	return normalize(mat3(normal_info.normal_matrix) * normal);
#endif

#ifdef USE_NORMALMAP_TANGENTSPACE
	vec3 mapN = texture(normal_map, v_normal_map_uv).xyz * 2.0 - 1.0;
	mapN.xy *= normal_info.normal_scale;
	return normalize(tbn * mapN);
#endif

#ifdef USE_BUMPMAP
	return perturbNormalArb(-v_view_position, normal, dHdxy_fwd(), faceDirection);
#endif

	return normal;
}

// normal_fragment_begin, then normal_fragment_maps.
vec3 shadingNormal() {
	float faceDirection = gl_FrontFacing ? 1.0 : -1.0;
	vec3 normal = beginNormal(faceDirection);
	mat3 tbn = mat3(1.0);

#ifdef USE_NORMALMAP_TANGENTSPACE
	tbn = tangentFrame(normal, v_normal_map_uv, faceDirection);
#endif

	return mapNormal(normal, tbn, faceDirection);
}
