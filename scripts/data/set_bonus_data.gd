class_name SetBonusData
extends Resource
## Set-Bonus einer Waffenklasse (GDD 8): Index 0 gilt ab 2 Waffen der Klasse, Index 4 ab 6.

const MIN_WEAPONS: int = 2

@export var weapon_class: StringName
@export var levels: Array[StatEffect] = []
## Lexikon: Übersetzungsschlüssel eines witzigen Satzes (Glühbirnen-Thema).
@export var lore_text: String = ""


## Modifikatoren für `count` Waffen dieser Klasse (leer unter 2).
func modifiers_for(count: int) -> Array[StatModifier]:
	if count < MIN_WEAPONS or levels.is_empty():
		return []
	return levels[mini(count - MIN_WEAPONS, levels.size() - 1)].modifiers
