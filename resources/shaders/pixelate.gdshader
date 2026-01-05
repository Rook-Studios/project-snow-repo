shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;
uniform float color_steps : hint_range(1.0, 64.0) = 32.0;
uniform bool dithering_enabled = true;

const mat4 bayer_matrix = mat4(
    vec4( 0.0,  8.0,  2.0, 10.0) / 16.0,
    vec4(12.0,  4.0, 14.0,  6.0) / 16.0,
    vec4( 3.0, 11.0,  1.0,  9.0) / 16.0,
    vec4(15.0,  7.0, 13.0,  5.0) / 16.0
);

float bayer4x4(vec2 fragcoord) {
    int x = int(fragcoord.x) & 3;
    int y = int(fragcoord.y) & 3;

    if (y == 0) return bayer_matrix[0][x];
    if (y == 1) return bayer_matrix[1][x];
    if (y == 2) return bayer_matrix[2][x];
    return bayer_matrix[3][x];
}

void fragment() {
    vec2 screen_uv = SCREEN_UV;
    vec2 tex_size = vec2(textureSize(screen_texture, 0));

    vec2 pixel_uv = floor(screen_uv * tex_size / pixel_size) * pixel_size / tex_size;

    vec4 color = texture(screen_texture, pixel_uv);

    // Quantize
    color.rgb = floor(color.rgb * color_steps) / color_steps;

    // Dither
    if (dithering_enabled) {
        float d = bayer4x4(FRAGCOORD.xy);
        color.rgb += d / color_steps;
        color.rgb = clamp(color.rgb, 0.0, 1.0);
    }

    COLOR = color;
}
