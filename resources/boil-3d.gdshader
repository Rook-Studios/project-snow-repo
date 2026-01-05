shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_texture;
uniform float boil_strength : hint_range(0.0, 1.0) = 0.3;
uniform float boil_interval : hint_range(0.01, 1.0) = 0.1;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Simulate frame-based boiling
	float snapped_time = floor(TIME / boil_interval);

	vec2 noise = vec2(
		rand(vec2(UV.y, snapped_time)),
		rand(vec2(snapped_time, UV.x))
	);

	vec2 jittered_uv = UV + (noise - 0.5) * boil_strength * 0.02;

	vec4 tex = texture(albedo_texture, jittered_uv);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}
