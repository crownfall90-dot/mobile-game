shader_type canvas_item;
// Фон: вечернее небо с мерцающими звёздами и тёплым свечением у горизонта.

uniform vec4 top_color : source_color = vec4(0.06, 0.04, 0.16, 1.0);
uniform vec4 mid_color : source_color = vec4(0.22, 0.09, 0.36, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.93, 0.42, 0.33, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.65, uv.y));
	col = mix(col, bottom_color.rgb, smoothstep(0.6, 1.05, uv.y));

	// мягкое свечение за башней
	float glow = 1.0 - smoothstep(0.0, 0.55, length((uv - vec2(0.5, 0.42)) * vec2(1.0, 0.7)));
	col += vec3(0.45, 0.25, 0.7) * glow * 0.18;

	// звёзды
	vec2 grid = uv * vec2(14.0, 26.0);
	vec2 id = floor(grid);
	vec2 gv = fract(grid) - 0.5;
	float h = hash(id);
	vec2 offs = vec2(hash(id + 1.3), hash(id + 7.1)) - 0.5;
	float d = length(gv - offs * 0.7);
	float twinkle = 0.5 + 0.5 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	float star = smoothstep(0.07, 0.0, d) * step(0.8, h) * twinkle * (1.0 - smoothstep(0.25, 0.65, uv.y));
	col += vec3(star);

	// силуэты холмов у горизонта (два слоя)
	float far_hills = 0.80 + 0.035 * sin(uv.x * 7.0 + 1.3) + 0.02 * sin(uv.x * 17.0);
	col = mix(col, vec3(0.36, 0.15, 0.32), smoothstep(far_hills, far_hills + 0.004, uv.y) * 0.85);
	float near_hills = 0.88 + 0.03 * sin(uv.x * 5.0 + 4.0) + 0.015 * sin(uv.x * 23.0 + 2.0);
	col = mix(col, vec3(0.16, 0.07, 0.2), smoothstep(near_hills, near_hills + 0.004, uv.y));

	COLOR = vec4(col, 1.0);
}
