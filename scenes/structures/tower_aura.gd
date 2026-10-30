class_name TowerAura
extends Node2D
## Sichtbarer Radius eines Frost- oder Heilturms am Boden: halbtransparente Fläche mit Rand.
## `flash()` lässt ihn kurz aufleuchten (Heilung).

const TOWERS: TowerConfig = preload("res://data/config/tower_config.tres")
const FLASH_TIME: float = 0.35
const FLASH_BOOST: float = 2.5
const SEGMENTS: int = 64

var color: Color = Color.WHITE
var radius: float = 0.0:
	set(value):
		if not is_equal_approx(value, radius):
			radius = value
			queue_redraw()

var _flash_left: float = 0.0


func flash() -> void:
	_flash_left = FLASH_TIME
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		queue_redraw()


func _draw() -> void:
	var boost: float = 1.0 + (FLASH_BOOST - 1.0) * clampf(_flash_left / FLASH_TIME, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, minf(1.0, TOWERS.aura_fill_alpha * boost)), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, SEGMENTS, Color(color, minf(1.0, 0.6 * boost)), TOWERS.aura_ring_width, true)
