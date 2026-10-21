class_name FrostNovaFx
extends Node2D
## Frostnova-Ring: eisblaue Scheibe, die auf den Radius wächst, mit Eiszacken am Rand, dann verblasst.

const FILL_COLOR: Color = Color("#BFEFFF40")
const RING_COLOR: Color = Color("#E6FAFF")
const SPIKE_COLOR: Color = Color("#8FE3FF")
const OUTLINE_COLOR: Color = Color("#2A1E2E")
const RING_WIDTH: float = 5.0
const SPIKES: int = 14
const SPIKE_LENGTH: float = 28.0
const SPIKE_WIDTH: float = 13.0
const GROW_TIME: float = 0.18
const HOLD_TIME: float = 0.08
const FADE_TIME: float = 0.25

var _radius: float = 0.0


func play(at: Vector2, radius: float) -> void:
	global_position = at
	rotation = randf() * TAU
	var tween: Tween = create_tween()
	tween.tween_method(_set_radius, radius * 0.2, radius, GROW_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.finished.connect(queue_free)


func _set_radius(value: float) -> void:
	_radius = value
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, FILL_COLOR)
	for i in SPIKES:
		var dir: Vector2 = Vector2.from_angle(TAU * i / SPIKES)
		var side: Vector2 = dir.orthogonal() * SPIKE_WIDTH * 0.5
		var base: Vector2 = dir * (_radius - SPIKE_LENGTH * 0.3)
		var tip: Vector2 = dir * (_radius + SPIKE_LENGTH * (0.7 if i % 2 == 0 else 0.4))
		var points: PackedVector2Array = [base + side, tip, base - side]
		draw_colored_polygon(points, SPIKE_COLOR)
		draw_polyline(PackedVector2Array([base + side, tip, base - side]), OUTLINE_COLOR, 2.0, true)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 56, OUTLINE_COLOR, RING_WIDTH * 1.7, true)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 56, RING_COLOR, RING_WIDTH, true)
