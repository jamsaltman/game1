shader_type canvas_item;

uniform vec2 source_size = vec2(480.0, 270.0);
uniform float display_scale = 1.0;
uniform float posterize_steps : hint_range(2.0, 8.0) = 5.0;
uniform float shadow_strength : hint_range(0.0, 0.35) = 0.08;

void fragment() {
	vec2 snapped_uv = floor(UV * source_size) / source_size;
	vec4 color = texture(TEXTURE, snapped_uv);
	color.rgb = floor(color.rgb * posterize_steps) / posterize_steps;

	float scan_mix = 0.94 + 0.06 * step(0.5, fract(UV.y * source_size.y * max(display_scale, 1.0) * 0.5));
	vec2 vignette_uv = UV * (1.0 - UV.yx);
	float vignette = pow(vignette_uv.x * vignette_uv.y * 18.0, 0.18);

	color.rgb *= scan_mix;
	color.rgb *= mix(1.0 - shadow_strength, 1.0, vignette);
	COLOR = color;
}
