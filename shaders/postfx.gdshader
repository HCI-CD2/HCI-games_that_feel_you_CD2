shader_type canvas_item;
render_mode unshaded;

// Full-screen look: pixelate, duotone grade (one shadow colour, one highlight
// colour, set per scene), colour reduction with ordered dithering, moving film
// grain and a vignette that reaches black at the corners. Sits on its own
// CanvasLayer above the background and below the UI, so text stays sharp.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float pixel_size : hint_range(1.0, 8.0) = 2.0;
uniform float levels : hint_range(2.0, 32.0) = 10.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.6;
uniform float grain : hint_range(0.0, 0.3) = 0.08;
uniform float vignette : hint_range(0.0, 1.0) = 0.95;
uniform float vignette_power : hint_range(0.1, 3.0) = 0.9;
uniform float brightness : hint_range(0.2, 1.5) = 0.9;
uniform float duotone : hint_range(0.0, 1.0) = 0.55;
uniform vec3 shadow_color : source_color = vec3(0.05, 0.22, 0.2);
uniform vec3 highlight_color : source_color = vec3(0.95, 0.83, 0.86);

// 4x4 Bayer threshold without an array, from the bit pattern of the cell coordinates.
float bayer4(vec2 p) {
	ivec2 ip = ivec2(mod(p, 4.0));
	int x = ip.x;
	int y = ip.y;
	int v = ((x ^ y) & 1) * 8 + (y & 1) * 4 + (((x ^ y) >> 1) & 1) * 2 + ((y >> 1) & 1);
	return (float(v) + 0.5) / 16.0;
}

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 screen_px = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(SCREEN_UV * screen_px / pixel_size);
	vec2 uv = (cell + 0.5) * pixel_size / screen_px;
	vec3 col = texture(screen_tex, uv).rgb;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 tone = mix(shadow_color, highlight_color, lum);
	col = mix(col, tone, duotone) * brightness;

	float d = (bayer4(cell) - 0.5) * dither_strength / levels;
	col = floor((col + d) * levels + 0.5) / levels;

	float g = (hash12(cell + fract(TIME) * 37.0) - 0.5) * grain;
	col += g;

	vec2 v = SCREEN_UV * (1.0 - SCREEN_UV);
	float vig = pow(clamp(v.x * v.y * 16.0, 0.0, 1.0), vignette_power);
	col *= mix(1.0, vig, vignette);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
