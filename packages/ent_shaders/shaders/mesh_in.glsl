// The varyings of shaders/mesh.vert, as every mesh fragment stage reads them (each uses a subset).
layout(location = 0) in vec3 v_normal;
layout(location = 1) in vec3 v_view_position;
layout(location = 2) in vec2 v_map_uv;
layout(location = 3) in vec2 v_alpha_map_uv;
layout(location = 4) in vec4 v_color;
layout(location = 5) in vec2 v_ao_map_uv;
layout(location = 6) in vec2 v_light_map_uv;
layout(location = 7) in vec2 v_emissive_map_uv;
layout(location = 8) in vec2 v_specular_map_uv;
layout(location = 9) in vec2 v_bump_map_uv;
layout(location = 10) in vec2 v_normal_map_uv;
layout(location = 11) in vec3 v_tangent;
layout(location = 12) in vec3 v_bitangent;
layout(location = 13) in vec3 v_world_position;
layout(location = 14) in vec2 v_clip_zw;
layout(location = 15) in vec4 v_uv;
layout(location = 16) in vec3 v_reflect;

#ifdef DASHED
layout(location = 17) in float v_line_distance;
#endif
