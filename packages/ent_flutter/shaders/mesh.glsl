// The vertex stage of every mesh material (shaders/mesh.vert; shaders/mesh_skin.vert defines SKINNING,
// shaders/mesh_morph.vert MORPHTARGETS, shaders/mesh_skin_morph.vert both, shaders/mesh_instance.vert INSTANCING,
// shaders/mesh_instance_morph.vert INSTANCING and MORPHTARGETS, shaders/mesh_instance_morph_texture.vert those and
// INSTANCING_MORPH, shaders/mesh_batch.vert BATCHING,
// shaders/mesh_dashed.vert DASHED: the lineDistance attribute of linedashed_vert): the uv_vertex, color_vertex,
// beginnormal/defaultnormal_vertex, normal_vertex (with tangents), the morph target chunks, the skinning chunks,
// displacementmap_vertex, project_vertex, worldpos_vertex and fog_vertex in one program, with the #ifdef features
// switched by uniforms (exception E-SHADERS). Attributes a geometry lacks are bound to default buffers that read
// as WebGL's disabled attribute value (0, 0, 0, 1). The raw uv and uv1 go to the fragment stage too, where the
// maps of MeshPhysicalMaterial apply their transforms (fifteen more uv varyings would not fit), and envmap_vertex
// computes vReflect for MeshBasicMaterial.
uniform VertInfo {
	mat4 projection_matrix;
	mat4 model_view_matrix;
	mat4 model_matrix;

	// mat3 uniforms are passed as the upper-left 3×3 of a mat4.
	mat4 normal_matrix;
	mat4 map_transform;
	mat4 alpha_map_transform;
	mat4 ao_map_transform;
	mat4 light_map_transform;
	mat4 emissive_map_transform;
	mat4 specular_map_transform;
	mat4 bump_map_transform;
	mat4 normal_map_transform;
	mat4 displacement_map_transform;

	// The uv channel (0: uv, 1: uv1) of each map: MAP_UV, ALPHAMAP_UV, ...
	float map_channel;
	float alpha_map_channel;
	float ao_map_channel;
	float light_map_channel;
	float emissive_map_channel;
	float specular_map_channel;
	float bump_map_channel;
	float normal_map_channel;
	float displacement_map_channel;

	// FLIP_SIDED: -1 for BackSide, else 1.
	float flip_sided;

	// USE_TANGENT, USE_DISPLACEMENTMAP: 1 or 0.
	float use_tangent;
	float use_displacement_map;
	float displacement_scale;
	float displacement_bias;

	// envmap_vertex without ENV_WORLDPOS: 0 off, 1 ENVMAP_MODE_REFLECTION, 2 ENVMAP_MODE_REFRACTION.
	float env_vertex;
	float refraction_ratio;
	float is_orthographic;
	vec3 camera_position;
	mat4 view_matrix;
#ifdef DASHED

	// LineDashedMaterial's scale (linedashed_vert).
	float line_scale;
#endif
} vert_info;

uniform sampler2D displacement_map;

in vec3 position;
in vec3 normal;
in vec2 uv;
in vec2 uv1;
in vec4 color;
in vec4 tangent;

#ifdef DASHED
in float lineDistance;
#endif

#ifdef SKINNING

// skinning_pars_vertex: the bone matrices in Skeleton.boneTexture, 4 RGBA float texels per bone (the matrix
// columns) in rows of a size × size texture, size a multiple of 4 (Skeleton.computeBoneTexture), so a bone's
// texels share a row. texelFetch as nearest samples at the texel centres: impellerc aborts on texelFetch.
uniform SkinInfo {
	mat4 bind_matrix;
	mat4 bind_matrix_inverse;

	// The bone texture's width and height (texelFetch's textureSize in the reference).
	float bone_texture_size;
} skin_info;

uniform sampler2D bone_texture;

in vec4 skinIndex;
in vec4 skinWeight;

vec4 boneTexel(float x, float y) {
	return textureLod(bone_texture, (vec2(x, y) + 0.5) / skin_info.bone_texture_size, 0.0);
}

mat4 getBoneMatrix(float i) {
	float size = skin_info.bone_texture_size;
	float j = i * 4.0;
	float x = mod(j, size);
	float y = floor(j / size);
	return mat4(boneTexel(x, y), boneTexel(x + 1.0, y), boneTexel(x + 2.0, y), boneTexel(x + 3.0, y));
}

#endif

#ifdef INSTANCING

// instancing_pars_vertex and USE_INSTANCING_COLOR: per-instance vertex buffers, as WebGL's instanced attributes;
// instanceMatrix (a mat4 attribute in the reference) as its four columns. An InstancedMesh without instanceColor binds
// white, and one with instanceColor but no vertexColors binds a white `color`.
in vec4 instanceMatrix0;
in vec4 instanceMatrix1;
in vec4 instanceMatrix2;
in vec4 instanceMatrix3;
in vec3 instanceColor;

#endif

#ifdef BATCHING

// batching_pars_vertex and USE_BATCHING_COLOR: the renderer draws a BatchedMesh one range at a time and writes
// the range's instance (getIndirectIndex( gl_DrawID )) matrix and color here from the batch's matrices and colors
// textures, so getBatchingMatrix and getBatchingColor read uniforms. `vertex_colors` is USE_COLOR: without it
// vColor starts at 1, as color_vertex.
uniform BatchInfo {
	mat4 matrix;
	vec4 color;
	float vertex_colors;
} batch_info;

#endif

#ifdef MORPHTARGETS

// morphtarget_pars_vertex: the reference's morph texture, with its texel layout (per target, a
// width × rows block of MORPHTARGETS_TEXTURE_STRIDE texels per vertex: position, normal, color), the targets
// stacked in rows of one 2D texture rather than the layers of a DataArrayTexture. The influences are a uniform
// array of at most MAX_MORPH_TARGETS (exception E-SHADERS); the program defines (MORPHTARGETS_COUNT, the stride,
// USE_MORPHNORMALS, USE_MORPHCOLORS) are uniforms; `height` is the texture's (rows × targets). `first` is the
// draw's first vertex of a non-indexed range, whose vertex buffers start there.
#define MAX_MORPH_TARGETS 64

uniform MorphInfo {
	vec4 influences[MAX_MORPH_TARGETS / 4];
	float base_influence;
	float count;
	float stride;
	float width;
	float rows;
	float height;
	float first;

	// USE_MORPHTARGETS and USE_MORPHNORMALS: 1 or 0; USE_MORPHCOLORS: 0 off, 1 USE_COLOR, 2 USE_COLOR_ALPHA.
	float positions;
	float normals;
	float colors;
#ifdef INSTANCING_MORPH

	// The size of InstancedMesh.morphTexture: per instance a row of the base influence, then one per target.
	float instance_width;
	float instance_height;
#endif
} morph_info;

uniform sampler2D morph_targets_texture;

#ifdef INSTANCING_MORPH

// morphinstance_vertex: InstancedMesh.morphTexture (setMorphAt), read at texel centres for texelFetch, the row
// gl_InstanceIndex (gl_InstanceID in the reference); texel 0 is morphTargetBaseInfluence, texel i + 1 influence i.
uniform sampler2D morph_texture;

float morphRow(int i) {
	if (i >= int(morph_info.instance_width)) {
		return 0.0;
	}

	vec2 texel = vec2(i, gl_InstanceIndex) + 0.5;
	return textureLod(morph_texture, texel / vec2(morph_info.instance_width, morph_info.instance_height), 0.0).r;
}

#endif

vec4 getMorph(int vertexIndex, int morphTargetIndex, int offset) {
	int width = int(morph_info.width);
	int texelIndex = vertexIndex * int(morph_info.stride) + offset;
	int y = texelIndex / width;
	int x = texelIndex - y * width;

	// texelFetch as a nearest sample at the texel's centre: impellerc aborts on texelFetch (as on textureSize).
	vec2 texel = vec2(x, y + morphTargetIndex * int(morph_info.rows)) + 0.5;
	return textureLod(morph_targets_texture, texel / vec2(morph_info.width, morph_info.height), 0.0);
}

float morphInfluence(int i) {
#ifdef INSTANCING_MORPH
	return morphRow(i + 1);
#else
	return morph_info.influences[i / 4][i % 4];
#endif
}

float morphBase() {
#ifdef INSTANCING_MORPH
	return morphRow(0);
#else
	return morph_info.base_influence;
#endif
}

#endif

layout(location = 0) out vec3 v_normal;
layout(location = 1) out vec3 v_view_position;
layout(location = 2) out vec2 v_map_uv;
layout(location = 3) out vec2 v_alpha_map_uv;
layout(location = 4) out vec4 v_color;
layout(location = 5) out vec2 v_ao_map_uv;
layout(location = 6) out vec2 v_light_map_uv;
layout(location = 7) out vec2 v_emissive_map_uv;
layout(location = 8) out vec2 v_specular_map_uv;
layout(location = 9) out vec2 v_bump_map_uv;
layout(location = 10) out vec2 v_normal_map_uv;
layout(location = 11) out vec3 v_tangent;
layout(location = 12) out vec3 v_bitangent;
layout(location = 13) out vec3 v_world_position;
layout(location = 14) out vec2 v_clip_zw;
layout(location = 15) out vec4 v_uv;
layout(location = 16) out vec3 v_reflect;

#ifdef DASHED
layout(location = 17) out float v_line_distance;
#endif

vec2 mapUv(mat4 transform, float channel) {
	return (mat3(transform) * vec3(channel > 0.5 ? uv1 : uv, 1.0)).xy;
}

void main() {
	v_map_uv = mapUv(vert_info.map_transform, vert_info.map_channel);
	v_alpha_map_uv = mapUv(vert_info.alpha_map_transform, vert_info.alpha_map_channel);
	v_ao_map_uv = mapUv(vert_info.ao_map_transform, vert_info.ao_map_channel);
	v_light_map_uv = mapUv(vert_info.light_map_transform, vert_info.light_map_channel);
	v_emissive_map_uv = mapUv(vert_info.emissive_map_transform, vert_info.emissive_map_channel);
	v_specular_map_uv = mapUv(vert_info.specular_map_transform, vert_info.specular_map_channel);
	v_bump_map_uv = mapUv(vert_info.bump_map_transform, vert_info.bump_map_channel);
	v_normal_map_uv = mapUv(vert_info.normal_map_transform, vert_info.normal_map_channel);
	v_uv = vec4(uv, uv1);

#ifdef DASHED
	v_line_distance = vert_info.line_scale * lineDistance;
#endif

	// A vec3 color is uploaded with alpha 1, so USE_COLOR and USE_COLOR_ALPHA are the same product.
	v_color = color;

#ifdef INSTANCING

	mat4 instanceMatrix = mat4(instanceMatrix0, instanceMatrix1, instanceMatrix2, instanceMatrix3);

	// color_vertex: USE_INSTANCING_COLOR, before morphcolor_vertex as in the reference.
	v_color.rgb *= instanceColor;

#endif

#ifdef BATCHING

	// batching_vertex, and color_vertex's USE_BATCHING_COLOR (white without setColorAt).
	mat4 instanceMatrix = batch_info.matrix;
	v_color = (batch_info.vertex_colors > 0.5 ? color : vec4(1.0)) * batch_info.color;

#endif

#ifdef MORPHTARGETS

	int morphVertex = gl_VertexIndex + int(morph_info.first);
	int morphTargets = int(morph_info.count);

	// morphcolor_vertex.
	if (morph_info.colors > 0.5) {
		vec4 morphed = v_color * morphBase();

		for (int i = 0; i < morphTargets; i++) {
			if (morphInfluence(i) != 0.0) {
				morphed += getMorph(morphVertex, i, 2) * morphInfluence(i);
			}
		}

		v_color = morph_info.colors > 1.5 ? morphed : vec4(morphed.rgb, v_color.a);
	}

#endif

	vec3 objectNormal = normal;
	vec3 objectTangent = tangent.xyz;

#ifdef MORPHTARGETS

	// morphnormal_vertex.
	if (morph_info.normals > 0.5) {
		objectNormal *= morphBase();

		for (int i = 0; i < morphTargets; i++) {
			if (morphInfluence(i) != 0.0) {
				objectNormal += getMorph(morphVertex, i, 1).xyz * morphInfluence(i);
			}
		}
	}

#endif

#ifdef SKINNING

	// skinbase_vertex and skinnormal_vertex.
	mat4 boneMatX = getBoneMatrix(skinIndex.x);
	mat4 boneMatY = getBoneMatrix(skinIndex.y);
	mat4 boneMatZ = getBoneMatrix(skinIndex.z);
	mat4 boneMatW = getBoneMatrix(skinIndex.w);
	mat4 skinMatrix = mat4(0.0);
	skinMatrix += skinWeight.x * boneMatX;
	skinMatrix += skinWeight.y * boneMatY;
	skinMatrix += skinWeight.z * boneMatZ;
	skinMatrix += skinWeight.w * boneMatW;
	skinMatrix = skin_info.bind_matrix_inverse * skinMatrix * skin_info.bind_matrix;
	objectNormal = vec4(skinMatrix * vec4(objectNormal, 0.0)).xyz;
	objectTangent = vec4(skinMatrix * vec4(objectTangent, 0.0)).xyz;

#endif

	vec3 transformedNormal = objectNormal;
	vec3 transformedTangent = objectTangent;

#if defined(INSTANCING) || defined(BATCHING)

	// defaultnormal_vertex: the instance's (or batched instance's) matrix in lieu of a per-instance normal matrix
	// (non-uniform scaling supported, shear not).
	mat3 im = mat3(instanceMatrix);
	transformedNormal /= vec3(dot(im[0], im[0]), dot(im[1], im[1]), dot(im[2], im[2]));
	transformedNormal = im * transformedNormal;
	transformedTangent = im * transformedTangent;

#endif

	v_normal = normalize(mat3(vert_info.normal_matrix) * transformedNormal * vert_info.flip_sided);

	if (vert_info.use_tangent > 0.5) {
		v_tangent = normalize((vert_info.model_view_matrix * vec4(transformedTangent, 0.0)).xyz);
		v_bitangent = normalize(cross(v_normal, v_tangent) * tangent.w) * vert_info.flip_sided;
	} else {
		v_tangent = vec3(0.0);
		v_bitangent = vec3(0.0);
	}

	vec3 transformed = position;

#ifdef MORPHTARGETS

	// morphtarget_vertex.
	if (morph_info.positions > 0.5) {
		transformed *= morphBase();

		for (int i = 0; i < morphTargets; i++) {
			if (morphInfluence(i) != 0.0) {
				transformed += getMorph(morphVertex, i, 0).xyz * morphInfluence(i);
			}
		}
	}

#endif

#ifdef SKINNING

	// skinning_vertex.
	vec4 skinVertex = skin_info.bind_matrix * vec4(transformed, 1.0);
	vec4 skinned = vec4(0.0);
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = (skin_info.bind_matrix_inverse * skinned).xyz;

#endif

	if (vert_info.use_displacement_map > 0.5) {
		vec2 displacement_uv = mapUv(vert_info.displacement_map_transform, vert_info.displacement_map_channel);
		transformed += normalize(objectNormal) * (
			textureLod(displacement_map, displacement_uv, 0.0).x * vert_info.displacement_scale
				+ vert_info.displacement_bias
		);
	}

#if defined(INSTANCING) || defined(BATCHING)

	// project_vertex and worldpos_vertex: the instance's (or batched instance's) matrix before the object's.
	vec4 local = instanceMatrix * vec4(transformed, 1.0);

#else

	vec4 local = vec4(transformed, 1.0);

#endif

	vec4 mv_position = vert_info.model_view_matrix * local;
	v_view_position = -mv_position.xyz;
	v_world_position = (vert_info.model_matrix * local).xyz;
	gl_Position = vert_info.projection_matrix * mv_position;
	v_clip_zw = gl_Position.zw;

	if (vert_info.env_vertex > 0.5) {
		vec3 cameraToVertex = vert_info.is_orthographic > 0.5
			? normalize(vec3(-vert_info.view_matrix[0][2], -vert_info.view_matrix[1][2], -vert_info.view_matrix[2][2]))
			: normalize(v_world_position - vert_info.camera_position);

		// transformNormalByInverseViewMatrix of the transformed (and FLIP_SIDED) normal.
		vec3 worldNormal = normalize((vec4(v_normal, 0.0) * vert_info.view_matrix).xyz);
		v_reflect = vert_info.env_vertex > 1.5
			? refract(cameraToVertex, worldNormal, vert_info.refraction_ratio)
			: reflect(cameraToVertex, worldNormal);
	} else {
		v_reflect = vec3(0.0);
	}
}
