class_name StatEffect
extends ItemEffect
## Ändert einen oder mehrere Stats dauerhaft.

@export var modifiers: Array[StatModifier] = []


func apply(player: Player) -> void:
	player.stats.add_modifiers(modifiers)


func get_modifiers() -> Array[StatModifier]:
	return modifiers
