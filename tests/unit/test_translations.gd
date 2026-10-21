extends GutTest
## Prüft die Übersetzungstabelle: jeder im Code genutzte Schlüssel existiert, Deutsch und Englisch sind gefüllt,
## keine hart codierten Texte in UI-Zuweisungen.

const CSV_PATH: String = "res://localization/strings.csv"
const CODE_DIRS: PackedStringArray = ["res://scenes", "res://scripts"]
## tr("SCHLÜSSEL") oder TextFormat.t("SCHLÜSSEL") mit festem Schlüssel.
const KEY_PATTERN: String = "(?:\\btr|TextFormat\\.t|\\bt)\\(\"([A-Z][A-Z0-9_]+)\"\\)"
## .text = "..." mit Buchstaben (Formatstrings wie "%d / %d" oder "x%d" sind erlaubt).
const HARDCODED_PATTERN: String = "\\.text\\s*=\\s*\"([^\"]*)\""

var _rows: Dictionary = {}


func before_all() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	assert_eq(Array(header), ["keys", "de", "en"])
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			_rows[row[0]] = row


func _code_files(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == "gd":
			result.append(dir_path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir_path):
		result.append_array(_code_files(dir_path.path_join(sub)))
	return result


func test_every_row_has_german_and_english() -> void:
	assert_gt(_rows.size(), 200)
	for key: String in _rows:
		var row: PackedStringArray = _rows[key]
		assert_ne(row[1].strip_edges(), "", "Deutsch fehlt: " + key)
		assert_ne(row[2].strip_edges(), "", "Englisch fehlt: " + key)
		assert_eq(row[1].count("%") - 2 * row[1].count("%%"), row[2].count("%") - 2 * row[2].count("%%"),
			"Platzhalter unterschiedlich: " + key)


func test_every_key_used_in_code_exists() -> void:
	var regex: RegEx = RegEx.create_from_string(KEY_PATTERN)
	var missing: PackedStringArray = []
	var found: int = 0
	for dir_path: String in CODE_DIRS:
		for path: String in _code_files(dir_path):
			for match: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
				found += 1
				var key: String = match.get_string(1)
				if not _rows.has(key) and key not in missing:
					missing.append("%s (%s)" % [key, path.get_file()])
	assert_gt(found, 100, "Suchmuster findet Schlüssel im Code")
	assert_eq(missing.size(), 0, "Fehlende Schlüssel: " + ", ".join(missing))


func test_no_hardcoded_ui_text() -> void:
	var regex: RegEx = RegEx.create_from_string(HARDCODED_PATTERN)
	var letters: RegEx = RegEx.create_from_string("[A-Za-zÄÖÜäöüß]{2,}")
	var found: PackedStringArray = []
	for dir_path: String in CODE_DIRS:
		for path: String in _code_files(dir_path):
			for match: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
				if letters.search(match.get_string(1)) != null:
					found.append("%s: \"%s\"" % [path.get_file(), match.get_string(1)])
	assert_eq(found.size(), 0, "Hart codierte Texte: " + ", ".join(found))


func test_english_locale_switches() -> void:
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(tr("MENU_QUIT"), "Quit")
	assert_eq(tr("CHAR_KERZE"), "Candle")
	TranslationServer.set_locale("de")
	assert_eq(tr("MENU_QUIT"), "Beenden")
	TranslationServer.set_locale(previous)
