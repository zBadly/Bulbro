class_name ExplosionFx
extends Node2D
## Explosionsring: wächst schnell auf den Radius und verblasst.

const FILL_COLOR: Color = Color("#FF8C42AA")
const RING_COLOR: Color = Color("#FFD43B")
const OUTLINE_COLOR: Color = Color("#2A1E2E")
const RING_WIDTH: float = 6.0
const GROW_TIME: float = 0.12
const FADE_TIME: float = 0.18

var fill_color: Color = FILL_COLOR
var ring_color: Color = RING_COLOR

var _radius: float = 0.0


func play(at: Vector2, radius: float) -> void:
	global_position = at
	var tween: Tween = create_tween()
	tween.tween_method(_set_radius, radius * 0.3, radius, GROW_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.finished.connect(queue_free)


func _set_radius(value: float) -> void:
	_radius = value
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, fill_color)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, OUTLINE_COLOR, RING_WIDTH * 1.6, true)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, ring_color, RING_WIDTH, true)
