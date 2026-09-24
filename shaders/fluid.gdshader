shader_type canvas_item;
// Превращает "поле" капель из FluidRenderer в гладкую жидкость.
// R = вода, G = лава, B = кислота.

uniform vec4 water_deep : source_color = vec4(0.10, 0.42, 0.98, 0.88);
uniform vec4 water_light : source_color = vec4(0.55, 0.90, 1.00, 0.95);
uniform vec4 lava_deep : source_color = vec4(0.95, 0.22, 0.06, 1.0);
uniform vec4 lava_light : source_color = vec4(1.00, 0.86, 0.30, 1.0);
uniform vec4 acid_deep : source_color = vec4(0.30, 0.80, 0.10, 0.95);
uniform vec4 acid_light : source_color = vec4(0.85, 1.00, 0.45, 1.0);
uniform float threshold = 0.5;

vec4 fluid_layer(float f, float f_up, vec4 deep, vec4 light, float glow_amount) {
	float body = smoothstep(threshold - 0.05, threshold + 0.05, f);
	float rim = 1.0 - smoothstep(threshold, threshold + 0.4, f);
	float top = clamp((f - f_up) * 5.0, 0.0, 1.0);
	vec3 col = mix(deep.rgb, light.rgb, clamp(rim * 0.7 + top, 0.0, 1.0));
	float a = body * mix(deep.a, light.a, top);
	float glow = smoothstep(0.06, threshold, f) * glow_amount * (1.0 - body);
	return vec4(mix(light.rgb, col, body), max(a, glow));
}

vec4 over(vec4 dst, vec4 src) {
	float a = src.a + dst.a * (1.0 - src.a);
	vec3 c = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / max(a, 0.0001);
	return vec4(c, a);
}

void fragment() {
	vec4 f = texture(TEXTURE, UV);
	vec4 fu = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0));

	vec4 water = fluid_layer(f.r, fu.r, water_deep, water_light, 0.0);
	vec4 lava = fluid_layer(f.g, fu.g, lava_deep, lava_light, 0.35);
	vec4 acid = fluid_layer(f.b, fu.b, acid_deep, acid_light, 0.25);

	// лава "дышит": бегущие светлые прожилки
	float veins = 0.5 + 0.5 * sin(TIME * 2.5 + UV.y * 90.0 + sin(UV.x * 60.0 + TIME) * 2.0);
	lava.rgb += vec3(0.25, 0.12, 0.0) * veins * step(threshold, f.g);

	vec4 c = over(vec4(0.0), water);
	c = over(c, acid);
	c = over(c, lava);
	COLOR = c;
}
