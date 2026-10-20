class_name Splat
extends Sprite2D
## Gepoolter Fleck am Boden, wo ein Gegner gestorben ist; verblasst und kehrt in den Pool zurück.

const START_ALPHA: float = 0.55
const HOLD_TIME: float = 0.8
const FADE_TIME: float = 2.2
const BASE_RADIUS: float = 20.0

var pool: ObjectPool

var _tween: Tween


func show_at(at: Vector2, radius: float, rng_angle: float) -> void:
	global_position = at
	rotation = rng_angle
	scale = Vector2.ONE * (radius / BASE_RADIUS)
	modulate.a = START_ALPHA
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.finished.connect(_release, CONNECT_ONE_SHOT)


func _release() -> void:
	if pool != null:
		pool.release(self)
	else:
		queue_free()
