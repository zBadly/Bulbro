extends Node
## Speichert dauerhaften Fortschritt (Freischaltungen, Optionen) als ConfigFile (Autoload "SaveManager").

const SAVE_PATH: String = "user://save.cfg"
const OPTIONS_SECTION: String = "options"
const LOCALE_KEY: String = "locale"
const DEFAULT_LOCALE: String = "de"

var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	load_game()
	TranslationServer.set_locale(get_value(OPTIONS_SECTION, LOCALE_KEY, DEFAULT_LOCALE))


func load_game() -> void:
	var err: Error = _config.load(SAVE_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("SaveManager: Spielstand konnte nicht geladen werden (%s)" % error_string(err))


func save_game() -> void:
	var err: Error = _config.save(SAVE_PATH)
	if err != OK:
		push_error("SaveManager: Spielstand konnte nicht gespeichert werden (%s)" % error_string(err))


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return _config.get_value(section, key, default)


func set_value(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
