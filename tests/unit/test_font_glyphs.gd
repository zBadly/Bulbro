extends GutTest
## Jedes Zeichen in Übersetzungen und String-Literalen des Codes muss in der Spielschrift vorhanden sein.
## Fehlende Glyphen (z. B. Pfeile, Emoji) fallen sonst auf Systemschriften zurück oder erscheinen als Kästchen.

const FONT: FontFile = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const CSV_PATH: String = "res://localization/strings.csv"
const CODE_DIRS: Array[String] = ["res://scripts", "res://scenes"]


func test_translations_use_only_font_glyphs() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	var missing: PackedStringArray = []
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		for column: int in range(1, row.size()):
			_collect_missing(row[column], row[0], missing)
	assert_eq(missing, PackedStringArray(), "Zeichen fehlen in der Schrift")


func test_code_literals_use_only_font_glyphs() -> void:
	var literal: RegEx = RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	var missing: PackedStringArray = []
	for path: String in _gd_files():
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for number: int in lines.size():
			var line: String = lines[number].strip_edges()
			if line.begins_with("#"):
				continue
			for found: RegExMatch in literal.search_all(line):
				_collect_missing(found.get_string(), "%s:%d" % [path, number + 1], missing)
	assert_eq(missing, PackedStringArray(), "Zeichen fehlen in der Schrift")


func _collect_missing(text: String, where: String, missing: PackedStringArray) -> void:
	for i: int in text.length():
		var code: int = text.unicode_at(i)
		if code >= 32 and not FONT.has_char(code):
			missing.append("U+%04X in %s" % [code, where])


func _gd_files() -> PackedStringArray:
	var result: PackedStringArray = []
	var pending: Array[String] = CODE_DIRS.duplicate()
	while not pending.is_empty():
		var dir_path: String = pending.pop_back()
		for sub: String in DirAccess.get_directories_at(dir_path):
			pending.append(dir_path.path_join(sub))
		for file_name: String in DirAccess.get_files_at(dir_path):
			if file_name.ends_with(".gd"):
				result.append(dir_path.path_join(file_name))
	return result
