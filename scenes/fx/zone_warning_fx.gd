class_name ZoneWarningFx
extends Node2D
## Pulsierende rote Warnzone am Boden; verschwindet nach der Vorwarnzeit.

const FILL_COLOR: Color = Color("#E74C3C55")
const RING_COLOR: Color = Color("#E74C3C")
const RING_WIDTH: float = 4.0
const PULSE_TIME: float = 0.25
const PULSE_ALPHA: float = 0.45

var _radius: float = 0.0


func play(at: Vector2, radius: float, duration: float) -> void:
	global_position = at
	_radius = radius
	z_index = -4
	queue_redraw()
	var pulse: Tween = create_tween().set_loops(maxi(1, ceili(duration / (PULSE_TIME * 2.0))))
	pulse.tween_property(self, "modulate:a", PULSE_ALPHA, PULSE_TIME)
	pulse.tween_property(self, "modulate:a", 1.0, PULSE_TIME)
	get_tree().create_timer(duration, false).timeout.connect(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, FILL_COLOR)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, RING_COLOR, RING_WIDTH, true)
