class_name ItemData
extends Resource
## Ein Item (GDD Abschnitt 9): Tier, Preis, optionales Limit, Tags und eine Liste von Effekten.

@export var id: StringName
@export var name_key: String = ""
@export_range(1, 4) var tier: int = 1
@export var icon: Texture2D
@export var price: int = 0
## Höchstanzahl pro Run (0 = unbegrenzt).
@export var limit: int = 0
## Für die Gewichtung im Shop nach Charakter-Vorlieben (z. B. hp, luck, economy).
@export var tags: Array[StringName] = []
@export var effects: Array[ItemEffect] = []
## Lexikon: Übersetzungsschlüssel eines witzigen Satzes (Glühbirnen-Thema).
@export var lore_text: String = ""


func get_modifiers() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for effect: ItemEffect in effects:
		result.append_array(effect.get_modifiers())
	return result


## Vollständige Beschreibung (BBCode): Stat-Änderungen plus Sondereffekte.
func get_description() -> String:
	var lines: PackedStringArray = [TextFormat.describe_modifiers(get_modifiers())]
	for effect: ItemEffect in effects:
		lines.append_array(effect.describe())
	return "\n".join(lines).strip_edges()


func is_at_limit(owned_count: int) -> bool:
	return limit > 0 and owned_count >= limit
