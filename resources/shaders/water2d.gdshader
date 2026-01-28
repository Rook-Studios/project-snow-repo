shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture;

uniform float effect_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform float wave_strength : hint_range(0.0, 0.05, 0.0005) = 0.012;
uniform float wave_speed : hint_range(0.0, 10.0, 0.1) = 2.0;
uniform float wave_scale : hint_range(0.1, 40.0, 0.1) = 10.0;

uniform vec3 tint_color : source_color = vec3(0.55, 0.75, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0, 0.01) = 0.25;

void fragment() {
	// SCREEN_UV samples what's already drawn behind this ColorRect.
	vec2 uv = SCREEN_UV;

	// Wavy refraction
	float t = TIME * wave_speed;
	vec2 wave = vec2(
		sin(uv.y * wave_scale + t),
		cos(uv.x * wave_scale + t)
	) * wave_strength * effect_strength;

	vec4 col = texture(screen_tex, uv + wave);

	// Blue-ish tint
	col.rgb = mix(col.rgb, col.rgb * tint_color, tint_amount * effect_strength);

	COLOR = col;
}
