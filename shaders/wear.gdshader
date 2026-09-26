shader_type canvas_item;
// Износ локации поверх чистого фона художника: пока ремонт не сделан, комната выцветшая,
// серо-бурая, в пятнах сырости и темнее по углам. wear — общий износ (1 — ничего не починено,
// 0 — всё готово). Вокруг каждой несделанной вещи — своё грязное пятно (spots), оно исчезает
// вместе с ремонтом этой вещи. Шум пятен — маленькая текстура, чтобы слабым телефонам было легко.

uniform float wear : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D stains : filter_linear, repeat_enable;
uniform vec2 aspect = vec2(1.0, 2.1667);   // пропорции сцены: пятна круглые, а не вытянутые
uniform int spot_count = 0;
uniform vec4 spots[8];                      // x, y (UV), радиус (UV по ширине), сила 0..1

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float local = 0.0;
	for (int i = 0; i < spot_count; i++) {
		vec4 s = spots[i];
		float d = length((UV - s.xy) * aspect);
		local = max(local, s.w * (1.0 - smoothstep(s.z * 0.35, s.z, d)));
	}
	float w = clamp(wear * 0.75 + local * 0.6, 0.0, 1.0);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(c.rgb, vec3(g), 0.55 * w);
	col *= mix(vec3(1.0), vec3(0.84, 0.79, 0.72), w);
	// пятна сырости и грязи: крупные мягкие разводы и мелкая крапинка
	float big = texture(stains, UV * aspect * 0.55).r;
	float small = texture(stains, UV * aspect * 3.0 + vec2(0.37, 0.11)).r;
	float stain = smoothstep(0.58, 0.9, big) * 0.75 + smoothstep(0.72, 0.9, small) * 0.25;
	col = mix(col, col * vec3(0.72, 0.65, 0.55), clamp(stain, 0.0, 1.0) * w);
	// углы темнее
	vec2 v = (UV - 0.5) * vec2(1.0, 0.8);
	col *= 1.0 - w * 0.35 * smoothstep(0.18, 0.62, length(v));
	COLOR = vec4(col, c.a);
}
