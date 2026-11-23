// HologramMaterial's fragment stage, ent's own (no reference shader): the color glows at fill where the surface
// faces the camera and up to fill + rim at its silhouette (a Fresnel term), cut by scanlines along world y and
// dimmed by a flicker, then the common output (output.glsl).
#include "shaders/output.glsl"
#include "shaders/mesh_in.glsl"
#include "shaders/maps.glsl"
#include "shaders/normals.glsl"

uniform FragInfo {
	vec3 diffuse;
	float opacity;
	float fill;
	float rim;
	float rim_power;
	float scanlines;
	float scanline_density;
	float scanline_speed;
	float flicker;
	float time;

	// 1 for an orthographic camera (the view direction is +z), else 0.
	float is_orthographic;
} frag_info;

out vec4 frag_color;

void main() {
	vec4 diffuseColor = diffuseOf(vec4(frag_info.diffuse, frag_info.opacity));
	vec3 normal = shadingNormal();
	vec3 viewDir = frag_info.is_orthographic > 0.5 ? vec3(0.0, 0.0, 1.0) : normalize(v_view_position);
	float glow = frag_info.fill + frag_info.rim * pow(1.0 - saturate(dot(normal, viewDir)), frag_info.rim_power);

	// The lines move up at scanline_speed: a line sits where y - time * speed is a multiple of 1 / density.
	float phase = frag_info.scanline_density * (v_world_position.y - frag_info.time * frag_info.scanline_speed);
	glow *= 1.0 - frag_info.scanlines * (0.5 - 0.5 * cos(6.28318530718 * phase));

	// A new random dimming 30 times a second.
	float noise = fract(sin(floor(frag_info.time * 30.0) * 12.9898) * 43758.5453);
	glow *= 1.0 - frag_info.flicker * noise;

	// Below 1 the glow is coverage, so normal blending shows the surface as see-through; above it, brightness, which
	// bloom can pick up. Additively blended, both give diffuse * opacity * glow.
	vec3 outgoingLight = diffuseColor.rgb * max(glow, 1.0);

	frag_color = outputColor(outgoingLight, diffuseColor.a * min(glow, 1.0), v_view_position.z);
	applyPolygonOffset();
}
