class_name StatBlock
extends Resource
## Basiswerte für eine Menge von Stats. Nicht eingetragene Stats gelten als 0.

@export var values: Dictionary[StringName, float] = {}


func get_value(stat: StringName) -> float:
	return values.get(stat, 0.0)
