class_name LexiconSection
extends RefCounted
## Abschnitt eines Lexikon-Eintrags: Überschrift plus BBCode-Text oder Tabelle (erste Zeile = Kopf).

var title: String = ""
var text: String = ""
var table: Array[PackedStringArray] = []


static func create_text(section_title: String, bbcode: String) -> LexiconSection:
	var section: LexiconSection = LexiconSection.new()
	section.title = section_title
	section.text = bbcode
	return section


static func create_table(section_title: String, rows: Array[PackedStringArray]) -> LexiconSection:
	var section: LexiconSection = LexiconSection.new()
	section.title = section_title
	section.table = rows
	return section


func is_table() -> bool:
	return not table.is_empty()


## Leer = kein Text und keine Tabellenzeile unter dem Kopf; leere Zellen zählen ebenfalls als leer
## (außer der Ecke oben links über den Zeilennamen).
func is_empty() -> bool:
	if title.strip_edges() == "":
		return true
	if not is_table():
		return text.strip_edges() == ""
	if table.size() < 2:
		return true
	for row_index: int in table.size():
		for column: int in table[row_index].size():
			if table[row_index][column].strip_edges() == "" and (row_index > 0 or column > 0):
				return true
	return false


## Text ohne BBCode, für die Suche.
func plain_text() -> String:
	var parts: PackedStringArray = [title, text]
	for row: PackedStringArray in table:
		parts.append(" ".join(row))
	return Lexicon.strip_bbcode(" ".join(parts))
