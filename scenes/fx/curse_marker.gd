class_name CurseMarker
extends Node2D
## Fluch-Symbol über einem Gegner mit Stapelzahl (Platzhalter-Grafik, gezeichnet).

const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const OUTLINE_COLOR: Color = Color("#2A1E2E")
const TEXT_COLOR: Color = Color.WHITE
const OUTLINE_WIDTH: float = 3.0
const FONT_SIZE: int = 14

var _stacks: int = 0


func _ready() -> void:
	visible = false


func show_stacks(stacks: int) -> void:
	_stacks = stacks
	visible = stacks > 0
	queue_redraw()


func _draw() -> void:
	if _stacks <= 0:
		return
	var radius: float = STATUS.curse_marker_radius
	draw_circle(Vector2.ZERO, radius + OUTLINE_WIDTH, OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, radius, STATUS.curse_marker_color)
	var font: Font = ThemeDB.fallback_font
	var text: String = str(_stacks)
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE)
	draw_string(font, Vector2(-size.x * 0.5, size.y * 0.3), text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE, TEXT_COLOR)
