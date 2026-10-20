extends Node
## Speichert dauerhaften Fortschritt (Freischaltungen, Gesamtfunken, Siege) und Optionen (Autoload "SaveManager").

const SAVE_PATH: String = "user://save.cfg"
const OPTIONS_SECTION: String = "options"
const PROGRESS_SECTION: String = "progress"
const LOCALE_KEY: String = "locale"
const DEFAULT_LOCALE: String = "de"
const LIGHTING_KEY: String = "lighting"
const FULLSCREEN_KEY: String = "fullscreen"
const CHARACTERS_KEY: String = "characters"
const TOTAL_SPARKS_KEY: String = "total_sparks"
const WINS_PREFIX: String = "wins_"
const VOLUME_KEYS: Dictionary[String, String] = {"Master": "volume_master", "Music": "volume_music", "SFX": "volume_sfx"}
const DEFAULT_VOLUME: float = 0.8
const MIN_LINEAR_VOLUME: float = 0.0001

var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	load_game()
	apply_options()


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


# --- Optionen ---

func apply_options() -> void:
	TranslationServer.set_locale(get_value(OPTIONS_SECTION, LOCALE_KEY, DEFAULT_LOCALE))
	for bus_name: String in VOLUME_KEYS:
		_apply_volume(bus_name, get_volume(bus_name))
	if DisplayServer.get_name() != "headless":
		var fullscreen: bool = get_value(OPTIONS_SECTION, FULLSCREEN_KEY, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func get_volume(bus_name: String) -> float:
	return get_value(OPTIONS_SECTION, VOLUME_KEYS[bus_name], DEFAULT_VOLUME)


func set_volume(bus_name: String, linear: float) -> void:
	set_value(OPTIONS_SECTION, VOLUME_KEYS[bus_name], linear)
	_apply_volume(bus_name, linear)


func _apply_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, MIN_LINEAR_VOLUME)))
		AudioServer.set_bus_mute(index, linear <= 0.0)


# --- Fortschritt ---

func is_character_unlocked(character_id: StringName) -> bool:
	return String(character_id) in get_value(PROGRESS_SECTION, CHARACTERS_KEY, PackedStringArray())


func unlock_character(character_id: StringName) -> void:
	var unlocked: PackedStringArray = get_value(PROGRESS_SECTION, CHARACTERS_KEY, PackedStringArray())
	if String(character_id) not in unlocked:
		unlocked.append(String(character_id))
		set_value(PROGRESS_SECTION, CHARACTERS_KEY, unlocked)


func get_total_sparks() -> int:
	return get_value(PROGRESS_SECTION, TOTAL_SPARKS_KEY, 0)


func add_total_sparks(amount: int) -> void:
	set_value(PROGRESS_SECTION, TOTAL_SPARKS_KEY, get_total_sparks() + amount)


func record_win(character_id: StringName) -> void:
	var key: String = WINS_PREFIX + String(character_id)
	set_value(PROGRESS_SECTION, key, get_value(PROGRESS_SECTION, key, 0) + 1)


func get_wins(character_id: StringName) -> int:
	return get_value(PROGRESS_SECTION, WINS_PREFIX + String(character_id), 0)
