class_name SpawnMarker
extends Sprite2D
## Gepooltes rotes X, das vor einem Gegner-Spawn pulsiert.

var pool: ObjectPool

var _tween: Tween


func show_at(world_position: Vector2) -> void:
	global_position = world_position
	modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	_tween = Juice.marker_pulse(self)


func release() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if pool != null:
		pool.release(self)
	else:
		queue_free()
