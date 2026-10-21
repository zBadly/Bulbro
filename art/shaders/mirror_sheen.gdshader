shader_type canvas_item;
// Spiegelbild (Spiegelkugel): Farbton und Transparenz kommen über modulate (COLOR).
// Ein schräger Glanzstreifen wandert alle sheen_period Sekunden über das Sprite, dazu leichtes Flimmern.

uniform float sheen_period = 1.8;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.6;
uniform float sheen_width = 0.12;
uniform float shimmer = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	// Streifen läuft von links oben nach rechts unten; außerhalb des Bildes pausiert er
	float phase = fract(TIME / sheen_period) * 2.4 - 0.7;
	float d = abs((UV.x + UV.y * 0.6) / 1.6 - phase);
	float band = 1.0 - smoothstep(0.0, sheen_width, d);
	tex.rgb = mix(tex.rgb, vec3(1.0), band * sheen_strength);
	tex.a *= 1.0 - shimmer * (0.5 + 0.5 * sin(TIME * 11.0));
	COLOR = tex;
}
