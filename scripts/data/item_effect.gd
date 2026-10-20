class_name ItemEffect
extends Resource
## Baustein eines Items oder Charakters (GDD 13: Effektsystem statt Spezialcode pro Item).


## Wendet den Effekt dauerhaft auf den Spieler an.
func apply(_player: Player) -> void:
	pass


## Stat-Modifikatoren, die der Effekt bewirkt (für Beschreibung und Vorher/Nachher-Vorschau).
func get_modifiers() -> Array[StatModifier]:
	return []
