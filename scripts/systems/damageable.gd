class_name Damageable
extends CharacterBody2D
## Basisklasse für alles, was Spielerwaffen treffen können (Gegner, Dummy, später Leuchtkristalle).
## Waffen suchen Ziele über die Gruppe GROUP.

const GROUP: StringName = &"enemies"

## Höhe des Trefferpunkts über dem Ursprung (Ursprung = Füße).
@export var hit_height: float = 0.0

var knockback_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group(GROUP)


func is_alive() -> bool:
	return true


func get_hit_position() -> Vector2:
	return global_position + Vector2(0.0, -hit_height)


## Von Unterklassen überschrieben.
func take_damage(_info: DamageInfo) -> void:
	pass


func apply_knockback(impulse: Vector2) -> void:
	knockback_velocity += impulse
