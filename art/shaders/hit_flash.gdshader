shader_type canvas_item;
// Weißes Aufblitzen bei Treffern. flash_amount wird per Tween von 1 auf 0 animiert (Juice.hit_flash).

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
// Status-Farbton (Frost, Brand, Fluch): Alpha = Stärke. Dunkle Konturen bleiben dunkel.
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

vec3 apply_tint(vec3 rgb) {
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	return mix(rgb, tint_color.rgb, tint_color.a * smoothstep(0.12, 0.26, lum));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(apply_tint(tex.rgb), flash_color.rgb, flash_amount), tex.a);
}
