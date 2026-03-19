shader_type canvas_item;

uniform vec2 source_size = vec2(480.0, 270.0);
uniform float display_scale = 1.0;
uniform float shadow_strength : hint_range(0.0, 0.2) = 0.04;
uniform float scanline_strength : hint_range(0.0, 0.12) = 0.045;
uniform float softness : hint_range(0.0, 0.5) = 0.12;
uniform float posterize_steps : hint_range(8.0, 32.0) = 20.0;
uniform float pixel_grid_strength : hint_range(0.0, 0.12) = 0.035;
uniform bool filter_enabled = true;

void fragment() {
	if (filter_enabled) {
		vec2 texel = 1.0 / max(source_size, vec2(1.0));
		vec2 sample_uv = (floor(UV * source_size) + 0.5) / source_size;
		vec4 center = texture(TEXTURE, sample_uv);
		vec4 color = center;

		if (display_scale > 1.0) {
			vec4 north = texture(TEXTURE, sample_uv + vec2(0.0, -texel.y));
			vec4 south = texture(TEXTURE, sample_uv + vec2(0.0, texel.y));
			vec4 east = texture(TEXTURE, sample_uv + vec2(texel.x, 0.0));
			vec4 west = texture(TEXTURE, sample_uv + vec2(-texel.x, 0.0));
			vec4 neighbor_mix = (north + south + east + west) * 0.25;
			color = mix(center, neighbor_mix, softness);
		}

		color.rgb = floor(color.rgb * posterize_steps) / posterize_steps;

		float scan_phase = fract(UV.y * source_size.y * max(display_scale, 1.0) * 0.5);
		float scan_mix = 1.0 - scanline_strength * smoothstep(0.15, 0.85, scan_phase);
		vec2 cell_uv = abs(fract(UV * source_size) - 0.5) * 2.0;
		float pixel_grid = 1.0 - pixel_grid_strength * smoothstep(0.72, 1.0, max(cell_uv.x, cell_uv.y));
		vec2 vignette_uv = UV * (1.0 - UV.yx);
		float vignette = pow(vignette_uv.x * vignette_uv.y * 18.0, 0.18);

		color.rgb *= scan_mix;
		color.rgb *= pixel_grid;
		color.rgb *= mix(1.0 - shadow_strength, 1.0, vignette);
		COLOR = color;
	} else {
		COLOR = texture(TEXTURE, UV);
	}
}
