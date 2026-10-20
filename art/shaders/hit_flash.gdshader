shader_type canvas_item;
// Weißes Aufblitzen bei Treffern. flash_amount wird per Tween von 1 auf 0 animiert (Juice.hit_flash).

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount), tex.a);
}
