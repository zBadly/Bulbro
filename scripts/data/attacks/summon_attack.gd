class_name SummonAttack
extends AttackPatternData
## Ruft Gegner um sich herum herbei (z. B. Rußmutter: Schattenlinge).

@export var enemy_data: EnemyData
@export var count: int = 1


func execute(enemy: Enemy, _cast: int) -> void:
	enemy.summon_requested.emit(enemy_data, count, enemy.global_position)
