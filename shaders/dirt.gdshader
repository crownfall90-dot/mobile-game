shader_type canvas_item;
// Земля для копания: маска клеток (1 — земля) с линейной фильтрацией даёт мягкий край.
// Внутри — тёплая мультяшная почва с камешками, у края — светлая кромка.

uniform vec2 cells = vec2(90.0, 160.0);
uniform vec4 soil : source_color = vec4(0.62, 0.42, 0.27, 1.0);
uniform vec4 soil_dark : source_color = vec4(0.49, 0.32, 0.2, 1.0);
uniform vec4 rim : source_color = vec4(0.86, 0.66, 0.42, 1.0);
uniform vec4 outline : source_color = vec4(0.33, 0.21, 0.13, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float m = texture(TEXTURE, UV).r;
	float a = smoothstep(0.42, 0.52, m);
	if (a <= 0.0) {
		discard;
	}
	vec2 px = UV * cells * 4.0;
	// крупные пятна и камешки
	vec2 g = floor(px / 22.0);
	vec2 f = fract(px / 22.0) - 0.5;
	float h = hash(g);
	vec2 o = vec2(hash(g + 3.1), hash(g + 7.7)) - 0.5;
	float pebble = 1.0 - smoothstep(0.12, 0.17, length(f - o * 0.5));
	vec3 col = mix(soil.rgb, soil_dark.rgb, step(0.55, h) * 0.6);
	col = mix(col, soil_dark.rgb * 0.8, pebble * step(0.35, h));
	col = mix(col, rim.rgb, pebble * step(h, 0.12));
	// кромка у края и тонкий контур
	float edge = 1.0 - smoothstep(0.52, 0.75, m);
	col = mix(col, rim.rgb, edge * 0.85);
	col = mix(col, outline.rgb, 1.0 - smoothstep(0.42, 0.5, m));
	COLOR = vec4(col, a);
}
