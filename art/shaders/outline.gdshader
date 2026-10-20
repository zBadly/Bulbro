shader_type canvas_item;
// Farbige Kontur um ein Sprite (z. B. rote Buff-Kontur des Verstärkers).
// Das Quad wird im Vertex-Shader um outline_width vergrößert, damit die Kontur nicht abgeschnitten wird.
// Enthält zusätzlich flash_amount, damit gebuffte Gegner bei Treffern ebenfalls aufblitzen.

uniform vec4 outline_color : source_color = vec4(0.906, 0.298, 0.235, 1.0);
uniform float outline_width : hint_range(0.0, 16.0) = 3.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

const int SAMPLES = 12;

// 1.0 innerhalb der Textur, 0.0 im vergrößerten Randbereich.
float inside(vec2 uv) {
	vec2 s = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return s.x * s.y;
}

void vertex() {
	VERTEX += (UV * 2.0 - 1.0) * outline_width;
}

void fragment() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 uv = (UV - 0.5) * (tex_size + 2.0 * outline_width) / tex_size + 0.5;
	vec4 base = texture(TEXTURE, uv) * inside(uv) * COLOR;
	base.rgb = mix(base.rgb, flash_color.rgb, flash_amount);

	float edge = 0.0;
	for (int i = 0; i < SAMPLES; i++) {
		float angle = TAU * float(i) / float(SAMPLES);
		vec2 offset = vec2(cos(angle), sin(angle)) * outline_width * TEXTURE_PIXEL_SIZE;
		vec2 p = uv + offset;
		edge = max(edge, texture(TEXTURE, p).a * inside(p));
	}
	vec4 outline = vec4(outline_color.rgb, outline_color.a * edge * COLOR.a);
	COLOR = mix(outline, base, base.a);
}
