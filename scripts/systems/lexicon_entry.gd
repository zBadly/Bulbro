class_name LexiconEntry
extends RefCounted
## Ein Eintrag im Lexikon (Charakter, Waffe, Item, Gegner, Waffenklasse oder Mechanik), fertig übersetzt.
## Wird von Lexicon aus den Resources gebaut und von der Lexikon-UI nur angezeigt.

var id: StringName
var tab: int = 0
## Die Resource, aus der der Eintrag gebaut wurde.
var source: Resource
var title: String = ""
## Kurze Einordnung unter dem Namen, z. B. "Tier II" oder "Elite".
var subtitle: String = ""
var icon: Texture2D
var color: Color = UiStyle.TEXT_COLOR
## Gesperrt: Silhouette mit Name und Freischaltbedingung.
var locked: bool = false
var lock_text: String = ""
var lore: String = ""
var sections: Array[LexiconSection] = []

# Filter- und Sortierwerte
var order: int = 0
var tier: int = 0
var tags: Array[StringName] = []
var classes: Array[StringName] = []
var melee: bool = false
## Gegnerart (Lexicon.EnemyKind).
var enemy_kind: int = 0

var _search_text: String = ""
var _search_text_full: String = ""


## Gesperrt und nicht über "Alles anzeigen" aufgedeckt: nur Silhouette, Name und Freischaltbedingung.
func is_hidden(show_all: bool) -> bool:
	return locked and not show_all


func add_text(section_title: String, bbcode: String) -> void:
	sections.append(LexiconSection.create_text(section_title, bbcode))


func add_table(section_title: String, rows: Array[PackedStringArray]) -> void:
	sections.append(LexiconSection.create_table(section_title, rows))


## Suche ohne Groß-/Kleinschreibung in Name, Einordnung, Abschnitten und Spruch.
## Verborgene Einträge (gesperrt, ohne "Alles anzeigen") verraten nur Name und Freischaltbedingung.
func matches(query: String, show_all: bool = false) -> bool:
	var needle: String = query.strip_edges().to_lower()
	if needle == "":
		return true
	if is_hidden(show_all):
		if _search_text == "":
			_search_text = Lexicon.strip_bbcode(" ".join([title, subtitle, lock_text])).to_lower()
		return _search_text.contains(needle)
	if _search_text_full == "":
		var parts: PackedStringArray = [title, subtitle, lock_text, lore]
		for section: LexiconSection in sections:
			parts.append(section.plain_text())
		_search_text_full = Lexicon.strip_bbcode(" ".join(parts)).to_lower()
	return _search_text_full.contains(needle)
