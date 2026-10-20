class_name SpawnGroupData
extends Resource
## Eine Spawn-Regel innerhalb einer Welle: welcher Gegner, wie oft, wie viele auf einmal.

@export var enemy: EnemyData
## Sekunden zwischen zwei Gruppen.
@export var interval: float = 0.0
@export var group_min: int = 1
@export var group_max: int = 1
## Erste Gruppe nach so vielen Sekunden Wellenzeit.
@export var start_time: float = 0.0
## Keine neuen Gruppen mehr nach dieser Wellenzeit (0 = bis zum Ende).
@export var end_time: float = 0.0
## Gruppe erscheint erst ab dieser Spannung (Flackerer ab Spannung 1).
@export var min_difficulty: int = 0
