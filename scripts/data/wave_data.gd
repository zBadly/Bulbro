class_name WaveData
extends Resource
## Definition einer Welle (GDD Abschnitt 2).

@export var wave_number: int = 1
@export var duration: float = 0.0
@export var groups: Array[SpawnGroupData] = []
## Sonderwellen für die Vorschau im Shop (Elite-Wellen folgen mit der Spannung).
@export var is_boss: bool = false
@export var is_elite: bool = false
