class_name EnemyBehavior
extends Node
## Basis der Verhaltens-Komponenten. Liefert pro Physik-Frame die gewünschte Geschwindigkeit.

var enemy: Enemy


## Beim (Wieder-)Aktivieren aus dem Pool aufgerufen.
func reset() -> void:
	pass


func get_velocity(_delta: float) -> Vector2:
	return Vector2.ZERO
