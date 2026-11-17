// The texture slots of the physical variants (shaders/physical.glsl). A Metal stage binds at most 16 sampler states
// (the iPhone 11's A13 skips a pipeline whose fragment stage declares 17, without an error; an M1 Mac binds 31), and
// Impeller gives every texture its own sampler state. So these stages declare 15 generic 2D samplers and env_map, and
// SlotInfo names the slot each map of the draw was bound to (ProgramVariant.bindTexture), or -1 for none (it reads as
// the renderer's fallback, opaque black). The light textures in use keep their pool slot (light_texture_k in slot k,
// read directly), so the shadow lookups that impellerc inlines into every unrolled light loop branch over 6 samplers,
// not 15; the DFG table keeps slot 13, the LTC tables of rect area lights slots 11 and 12 while the frame has such
// lights, and the transmission target, read 4 times per bicubic sample, slot 14 (TRANSMISSION).
//
// impellerc inlines every call, so a slot read written at each map's call site became a 15-way branch per site
// (13 sites with the standard maps, 195 sample instructions, a third of its MSL). Instead readSlots (physical.glsl)
// reads every map once at the start of main, in a loop that stays a loop: one 15-way branch for the whole
// stage. Each map's read lands in slot_reads at its index below, and texture(name, uv) of a map returns it; the
// uv argument is ignored, as readSlots read the map at the same uv. Included first.
#define TEXTURE_SLOTS

// SLOT_MAPS: the stage reads a map through the slots. A variant without maps reads none, so the compiler would drop
// SlotInfo, UvInfo, readSlots and the map slots (6 to 10 and 14) while the reflection keeps them, and the renderer
// would bind them out of range (a bus error on Metal, a crash under SwiftShader); such a variant declares none of
// them, and the renderer binds only the light, LTC and DFG slots (ProgramVariant.endSlots).
#if defined(USE_MAP) || defined(USE_ALPHAMAP) || defined(USE_AOMAP) || defined(USE_LIGHTMAP) \
	|| defined(USE_EMISSIVEMAP) || defined(USE_BUMPMAP) || defined(USE_NORMALMAP_TANGENTSPACE) \
	|| defined(USE_NORMALMAP_OBJECTSPACE) || PHYSICAL_MAPS
#define SLOT_MAPS
#endif


uniform sampler2D slot_0;
uniform sampler2D slot_1;
uniform sampler2D slot_2;
uniform sampler2D slot_3;
uniform sampler2D slot_4;
uniform sampler2D slot_5;
#ifdef SLOT_MAPS
uniform sampler2D slot_6;
uniform sampler2D slot_7;
uniform sampler2D slot_8;
uniform sampler2D slot_9;
uniform sampler2D slot_10;
#endif
uniform sampler2D slot_11;
uniform sampler2D slot_12;
uniform sampler2D slot_13;
#if defined(SLOT_MAPS) || defined(TRANSMISSION)
uniform sampler2D slot_14;
#endif
uniform samplerCube env_map;

#ifdef SLOT_MAPS
uniform SlotInfo {
	float map;
	float alpha_map;
	float specular_map;
	float emissive_map;
	float ao_map;
	float light_map;
	float bump_map;
	float normal_map;
	float roughness_map;
	float metalness_map;
	float clearcoat_map;
	float clearcoat_roughness_map;
	float clearcoat_normal_map;
	float sheen_color_map;
	float sheen_roughness_map;
	float iridescence_map;
	float iridescence_thickness_map;
	float anisotropy_map;
	float specular_intensity_map;
	float specular_color_map;
	float diffuse_roughness_map;
	float transmission_map;
	float thickness_map;
} slot_info;
#endif

#ifdef SLOT_MAPS
vec4 slotTexture(float slot, vec2 uv) {
	int i = int(floor(slot + 0.5));

	if (i == 0) {
		return texture(slot_0, uv);
	}

	if (i == 1) {
		return texture(slot_1, uv);
	}

	if (i == 2) {
		return texture(slot_2, uv);
	}

	if (i == 3) {
		return texture(slot_3, uv);
	}

	if (i == 4) {
		return texture(slot_4, uv);
	}

	if (i == 5) {
		return texture(slot_5, uv);
	}

	if (i == 6) {
		return texture(slot_6, uv);
	}

	if (i == 7) {
		return texture(slot_7, uv);
	}

	if (i == 8) {
		return texture(slot_8, uv);
	}

	if (i == 9) {
		return texture(slot_9, uv);
	}

	if (i == 10) {
		return texture(slot_10, uv);
	}

	if (i == 11) {
		return texture(slot_11, uv);
	}

	if (i == 12) {
		return texture(slot_12, uv);
	}

	if (i == 13) {
		return texture(slot_13, uv);
	}

	if (i == 14) {
		return texture(slot_14, uv);
	}

	return vec4(0.0, 0.0, 0.0, 1.0);
}
#endif

vec4 env_map_texture(vec3 direction) {
	return texture(env_map, direction);
}

vec4 env_map_lod(vec3 direction, float lod) {
	return textureLod(env_map, direction, lod);
}

// The index in slot_reads of each map's read: the maps of maps.glsl and normals.glsl (the bump map three times,
// at the uv and one pixel to the right and up), then the physical maps in the order of UvInfo.
#define READ_MAP 0
#define READ_ALPHA_MAP 1
#define READ_SPECULAR_MAP 2
#define READ_EMISSIVE_MAP 3
#define READ_AO_MAP 4
#define READ_LIGHT_MAP 5
#define READ_BUMP_MAP 6
#define READ_BUMP_MAP_DX 7
#define READ_BUMP_MAP_DY 8
#define READ_NORMAL_MAP 9
#define READ_ROUGHNESS_MAP 10
#define READ_METALNESS_MAP 11
#define READ_CLEARCOAT_MAP 12
#define READ_CLEARCOAT_ROUGHNESS_MAP 13
#define READ_CLEARCOAT_NORMAL_MAP 14
#define READ_SHEEN_COLOR_MAP 15
#define READ_SHEEN_ROUGHNESS_MAP 16
#define READ_IRIDESCENCE_MAP 17
#define READ_IRIDESCENCE_THICKNESS_MAP 18
#define READ_ANISOTROPY_MAP 19
#define READ_SPECULAR_INTENSITY_MAP 20
#define READ_SPECULAR_COLOR_MAP 21
#define READ_DIFFUSE_ROUGHNESS_MAP 22
#define READ_TRANSMISSION_MAP 23
#define READ_THICKNESS_MAP 24

// The reads of the stage's maps: the first 12, with PHYSICAL 23, with TRANSMISSION all 25. A map past them reads as
// opaque black (its layer is off in the variant).
#if defined(TRANSMISSION)
#define SLOT_READS 25
#elif defined(PHYSICAL)
#define SLOT_READS 23
#else
#define SLOT_READS 12
#endif

vec4 slot_reads[SLOT_READS];

vec4 map_texture(vec2 uv) {
	return slot_reads[READ_MAP];
}

vec4 alpha_map_texture(vec2 uv) {
	return slot_reads[READ_ALPHA_MAP];
}

vec4 specular_map_texture(vec2 uv) {
	return slot_reads[READ_SPECULAR_MAP];
}

vec4 emissive_map_texture(vec2 uv) {
	return slot_reads[READ_EMISSIVE_MAP];
}

vec4 ao_map_texture(vec2 uv) {
	return slot_reads[READ_AO_MAP];
}

vec4 light_map_texture(vec2 uv) {
	return slot_reads[READ_LIGHT_MAP];
}

vec4 bump_map_texture(vec2 uv) {
	return slot_reads[READ_BUMP_MAP];
}

vec4 normal_map_texture(vec2 uv) {
	return slot_reads[READ_NORMAL_MAP];
}

vec4 light_texture_0_texture(vec2 uv) {
	return texture(slot_0, uv);
}

vec4 light_texture_1_texture(vec2 uv) {
	return texture(slot_1, uv);
}

vec4 light_texture_2_texture(vec2 uv) {
	return texture(slot_2, uv);
}

vec4 light_texture_3_texture(vec2 uv) {
	return texture(slot_3, uv);
}

vec4 light_texture_4_texture(vec2 uv) {
	return texture(slot_4, uv);
}

vec4 light_texture_5_texture(vec2 uv) {
	return texture(slot_5, uv);
}

vec4 dfg_lut_texture(vec2 uv) {
	return texture(slot_13, uv);
}

// The LTC tables of rect area lights, in slots 11 and 12 while the frame has them (ltcSlots).
vec4 ltc_1_texture(vec2 uv) {
	return texture(slot_11, uv);
}

vec4 ltc_2_texture(vec2 uv) {
	return texture(slot_12, uv);
}

vec4 roughness_map_texture(vec2 uv) {
	return slot_reads[READ_ROUGHNESS_MAP];
}

vec4 metalness_map_texture(vec2 uv) {
	return slot_reads[READ_METALNESS_MAP];
}

vec4 clearcoat_map_texture(vec2 uv) {
#if READ_CLEARCOAT_MAP < SLOT_READS
	return slot_reads[READ_CLEARCOAT_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 clearcoat_roughness_map_texture(vec2 uv) {
#if READ_CLEARCOAT_ROUGHNESS_MAP < SLOT_READS
	return slot_reads[READ_CLEARCOAT_ROUGHNESS_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 clearcoat_normal_map_texture(vec2 uv) {
#if READ_CLEARCOAT_NORMAL_MAP < SLOT_READS
	return slot_reads[READ_CLEARCOAT_NORMAL_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 sheen_color_map_texture(vec2 uv) {
#if READ_SHEEN_COLOR_MAP < SLOT_READS
	return slot_reads[READ_SHEEN_COLOR_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 sheen_roughness_map_texture(vec2 uv) {
#if READ_SHEEN_ROUGHNESS_MAP < SLOT_READS
	return slot_reads[READ_SHEEN_ROUGHNESS_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 iridescence_map_texture(vec2 uv) {
#if READ_IRIDESCENCE_MAP < SLOT_READS
	return slot_reads[READ_IRIDESCENCE_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 iridescence_thickness_map_texture(vec2 uv) {
#if READ_IRIDESCENCE_THICKNESS_MAP < SLOT_READS
	return slot_reads[READ_IRIDESCENCE_THICKNESS_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 anisotropy_map_texture(vec2 uv) {
#if READ_ANISOTROPY_MAP < SLOT_READS
	return slot_reads[READ_ANISOTROPY_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 specular_intensity_map_texture(vec2 uv) {
#if READ_SPECULAR_INTENSITY_MAP < SLOT_READS
	return slot_reads[READ_SPECULAR_INTENSITY_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 specular_color_map_texture(vec2 uv) {
#if READ_SPECULAR_COLOR_MAP < SLOT_READS
	return slot_reads[READ_SPECULAR_COLOR_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 diffuse_roughness_map_texture(vec2 uv) {
#if READ_DIFFUSE_ROUGHNESS_MAP < SLOT_READS
	return slot_reads[READ_DIFFUSE_ROUGHNESS_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 transmission_map_texture(vec2 uv) {
#if READ_TRANSMISSION_MAP < SLOT_READS
	return slot_reads[READ_TRANSMISSION_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 thickness_map_texture(vec2 uv) {
#if READ_THICKNESS_MAP < SLOT_READS
	return slot_reads[READ_THICKNESS_MAP];
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

#if defined(SLOT_MAPS) || defined(TRANSMISSION)
vec4 transmission_sampler_map_lod(vec2 uv, float lod) {
	return textureLod(slot_14, uv, lod);
}
#endif

#define texture(name, uv) name##_texture(uv)
#define textureLod(name, uv, lod) name##_lod(uv, lod)
