class_name CurseMarker
extends Node2D
## Fluch-Symbol über einem Gegner: violette Raute mit Auge und Stapelzahl (1-3) unten rechts.

const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const ICON: Texture2D = preload("res://art/fx/curse_mark.svg")
const FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const OUTLINE_COLOR: Color = Color("#2A1E2E")
const TEXT_COLOR: Color = Color.WHITE
const OUTLINE_WIDTH: float = 2.5
const FONT_SIZE: int = 15
## Lage des Stapel-Abzeichens relativ zur Symbolmitte.
const BADGE_OFFSET: Vector2 = Vector2(11.0, 7.0)
const POP_SCALE: float = 1.35
const POP_TIME: float = 0.15

var _stacks: int = 0


func _ready() -> void:
	visible = false
	scale = Vector2.ONE * STATUS.curse_marker_scale


func show_stacks(stacks: int) -> void:
	var grew: bool = stacks > _stacks
	_stacks = stacks
	visible = stacks > 0
	queue_redraw()
	if grew and is_inside_tree():
		scale = Vector2.ONE * STATUS.curse_marker_scale * POP_SCALE
		create_tween().tween_property(self, "scale", Vector2.ONE * STATUS.curse_marker_scale, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if _stacks <= 0:
		return
	draw_texture(ICON, -ICON.get_size() * 0.5)
	var radius: float = STATUS.curse_marker_radius
	draw_circle(BADGE_OFFSET, radius + OUTLINE_WIDTH, OUTLINE_COLOR)
	draw_circle(BADGE_OFFSET, radius, STATUS.curse_marker_color)
	var text: String = str(_stacks)
	var size: Vector2 = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var baseline: Vector2 = BADGE_OFFSET + Vector2(-size.x * 0.5, FONT.get_ascent(FONT_SIZE) * 0.5 - 1.0)
	draw_string_outline(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, OUTLINE_COLOR)
	draw_string(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
