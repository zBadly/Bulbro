class_name AttackPatternData
extends Resource
## Angriffsmuster eines Elites oder Bosses. `cast` zählt die bisherigen Ausführungen (für Spiralen).

@export var cooldown: float = 0.0


func execute(_enemy: Enemy, _cast: int) -> void:
	pass
