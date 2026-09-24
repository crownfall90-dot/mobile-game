shader_type canvas_item;

uniform sampler2D restored : source_color, filter_linear;
uniform int repair_mask = 0;

float area(vec2 uv, vec4 rect) {
	float feather = 0.025;
	float left = rect.x <= 0.0 ? 1.0 : smoothstep(rect.x - feather, rect.x + feather, uv.x);
	float top = rect.y <= 0.0 ? 1.0 : smoothstep(rect.y - feather, rect.y + feather, uv.y);
	float right = rect.z >= 1.0 ? 1.0 : 1.0 - smoothstep(rect.z - feather, rect.z + feather, uv.x);
	float bottom = rect.w >= 1.0 ? 1.0 : 1.0 - smoothstep(rect.w - feather, rect.w + feather, uv.y);
	return left * top * right * bottom;
}

void fragment() {
	float repaired = 0.0;
	if ((repair_mask & 1) != 0) repaired = max(repaired, area(UV, vec4(0.76, 0.30, 1.0, 0.64)));
	if ((repair_mask & 2) != 0) repaired = max(repaired, area(UV, vec4(0.38, 0.0, 0.62, 0.20)));
	if ((repair_mask & 4) != 0) repaired = max(repaired, area(UV, vec4(0.0, 0.05, 0.26, 0.36)));
	if ((repair_mask & 8) != 0) repaired = max(repaired, area(UV, vec4(0.73, 0.51, 1.0, 0.94)));
	if ((repair_mask & 16) != 0) repaired = max(repaired, area(UV, vec4(0.0, 0.50, 0.36, 0.93)));
	if ((repair_mask & 32) != 0) repaired = max(repaired, area(UV, vec4(0.0, 0.20, 0.39, 0.55)));
	if ((repair_mask & 64) != 0) repaired = max(repaired, area(UV, vec4(0.65, 0.18, 0.86, 0.40)));
	if ((repair_mask & 128) != 0) repaired = max(repaired, area(UV, vec4(0.72, 0.28, 0.91, 0.44)));
	if ((repair_mask & 256) != 0) repaired = max(repaired, area(UV, vec4(0.0, 0.0, 1.0, 0.57)));
	if ((repair_mask & 512) != 0) repaired = 1.0;
	COLOR = mix(texture(TEXTURE, UV), texture(restored, UV), repaired);
}
