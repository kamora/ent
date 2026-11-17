// The maps the mesh materials share, as the reference's map, color, alphamap, alphatest, specularmap, emissivemap,
// aomap and lightmap chunks read them. A material kind reads the subset its shader in the reference includes; a
// variant defines the flags of the maps it uses (USE_MAP, USE_ALPHAMAP, USE_AOMAP, USE_LIGHTMAP, USE_EMISSIVEMAP,
// USE_SPECULARMAP) and compiles the others out.
uniform MapInfo {

	// USE_ALPHATEST when alpha_test is above 0.
	float alpha_test;
	float ao_map_intensity;
	float light_map_intensity;
} map_info;

// A stage that reads its textures through slots (slots.glsl) declares none of these samplers by name.
#ifndef TEXTURE_SLOTS
#ifdef USE_MAP
uniform sampler2D map;
#endif

#ifdef USE_ALPHAMAP
uniform sampler2D alpha_map;
#endif

#ifdef USE_AOMAP
uniform sampler2D ao_map;
#endif

#ifdef USE_LIGHTMAP
uniform sampler2D light_map;
#endif

#ifdef USE_EMISSIVEMAP
uniform sampler2D emissive_map;
#endif

#ifdef USE_SPECULARMAP
uniform sampler2D specular_map;
#endif
#endif

// map_fragment, color_fragment, alphamap_fragment and alphatest_fragment applied to [color].
vec4 diffuseOf(vec4 color) {
#ifdef USE_MAP
	color *= texture(map, v_map_uv);
#endif

	// Vertex colors, always applied: white when the draw has none (the vertex stage owns them, with instance and
	// batch colors).
	color *= v_color;

#ifdef USE_ALPHAMAP
	color.a *= texture(alpha_map, v_alpha_map_uv).g;
#endif

	if (map_info.alpha_test > 0.0 && color.a < map_info.alpha_test) {
		discard;
	}

	return color;
}

// specularmap_fragment.
float specularStrengthOf() {
#ifdef USE_SPECULARMAP
	return texture(specular_map, v_specular_map_uv).r;
#endif

	return 1.0;
}

// emissivemap_fragment applied to [emissive].
vec3 emissiveOf(vec3 emissive) {
#ifdef USE_EMISSIVEMAP
	return emissive * texture(emissive_map, v_emissive_map_uv).rgb;
#endif

	return emissive;
}

// The ambient occlusion factor of aomap_fragment (1 without an aoMap).
float ambientOcclusion() {
#ifdef USE_AOMAP
	return (texture(ao_map, v_ao_map_uv).r - 1.0) * map_info.ao_map_intensity + 1.0;
#endif

	return 1.0;
}
