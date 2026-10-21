extends Node
## Dauerhafter Spielstand als versioniertes JSON (Autoload "SaveManager"): Optionen, Freischaltungen,
## gewonnene Spannungsstufen je Charakter, Statistiken und ein unterbrochener Run (gespeichert am Shop-Beginn).
## Ältere Formate (save.cfg und JSON-Version 1) werden beim Laden migriert.

const SAVE_PATH: String = "user://save.json"
const LEGACY_CFG_PATH: String = "user://save.cfg"
const TEMP_SUFFIX: String = ".tmp"
## Aktuelle Version des Speicherformats. Bei Änderungen erhöhen und eine Migration in _migrate ergänzen.
const SAVE_VERSION: int = 2
const JSON_INDENT: String = "\t"

# Optionen
const LOCALE_KEY: String = "locale"
const DEFAULT_LOCALE: String = "de"
const LIGHTING_KEY: String = "lighting"
const FULLSCREEN_KEY: String = "fullscreen"
const SCREENSHAKE_KEY: String = "screenshake"
const MANUAL_AIM_KEY: String = "manual_aim"
## Barrierefreiheit: Bildschirmblitze stark abschwächen.
const REDUCED_FX_KEY: String = "reduced_effects"
## Barrierefreiheit: Gegnerwerte in Prozent (25-100).
const ENEMY_HP_KEY: String = "enemy_hp_pct"
const ENEMY_DAMAGE_KEY: String = "enemy_damage_pct"
const ENEMY_SPEED_KEY: String = "enemy_speed_pct"
const ASSIST_MIN_PCT: float = 25.0
const ASSIST_MAX_PCT: float = 100.0
const VOLUME_KEYS: Dictionary[String, String] = {"Master": "volume_master", "Music": "volume_music", "SFX": "volume_sfx"}
const DEFAULT_VOLUME: float = 0.8
const MIN_LINEAR_VOLUME: float = 0.0001

# Statistiken
const STAT_TOTAL_SPARKS: String = "total_sparks"
const STAT_KILLS: String = "kills"
const STAT_RUNS: String = "runs"
const STAT_WINS: String = "wins"
const STAT_BURN_KILLS: String = "burn_kills"
const STAT_CRYSTALS: String = "crystals"
## Kills pro Waffe: "kills_<waffen-id>".
const WEAPON_KILLS_PREFIX: String = "kills_"

## Pfad der Spielstanddatei (Tests setzen über use_path einen eigenen).
var save_path: String = SAVE_PATH

var _data: Dictionary = {}


func _ready() -> void:
	load_game()
	apply_options()


## Für Tests: eigenen Spielstand verwenden (wird frisch geladen).
func use_path(path: String) -> void:
	save_path = path
	load_game()


func reset() -> void:
	_data = _defaults()


func load_game() -> void:
	if FileAccess.file_exists(save_path):
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(save_path)) == OK and json.data is Dictionary:
			_data = _migrate(json.data)
			return
		push_warning("SaveManager: Spielstand unlesbar, starte mit leerem Stand")
	elif save_path == SAVE_PATH and FileAccess.file_exists(LEGACY_CFG_PATH):
		_data = _migrate(_from_legacy_cfg())
		return
	_data = _defaults()


## Schreibt erst in eine Temp-Datei und benennt sie dann um, damit ein Absturz keinen halben Stand hinterlässt.
func save_game() -> void:
	_data["version"] = SAVE_VERSION
	var temp_path: String = save_path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Spielstand konnte nicht gespeichert werden (%s)" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(_data, JSON_INDENT))
	file.close()
	var err: Error = DirAccess.rename_absolute(temp_path, save_path)
	if err != OK:
		push_error("SaveManager: Umbenennen fehlgeschlagen (%s)" % error_string(err))


func get_version() -> int:
	return _data.get("version", SAVE_VERSION)


# --- Format und Migration ---

func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"options": {},
		"progress": {"characters": [], "items": [], "challenges": [], "won_difficulties": {}, "challenge_best": {}},
		"stats": {STAT_TOTAL_SPARKS: 0, STAT_KILLS: 0, STAT_RUNS: 0, STAT_WINS: 0},
		"run": {},
	}


## Bringt ältere Stände schrittweise auf SAVE_VERSION. Fehlende Felder werden mit Standardwerten ergänzt.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 1))
	if version < 2:
		# Version 1 kannte weder gewonnene Spannungsstufen noch Challenges oder Run-Spielstände;
		# Siege lagen als "wins_<id>"-Zähler im Fortschritt.
		var progress: Dictionary = data.get("progress", {})
		var won: Dictionary = {}
		for key: String in progress.keys():
			if key.begins_with("wins_"):
				won[key.trim_prefix("wins_")] = [0]
				progress.erase(key)
		progress["won_difficulties"] = won
		data["progress"] = progress
		version = 2
	var result: Dictionary = _defaults()
	for section: String in ["options", "stats", "run"]:
		result[section].merge(data.get(section, {}), true)
	result["progress"].merge(data.get("progress", {}), true)
	result["version"] = SAVE_VERSION
	return result


## Übernimmt den alten ConfigFile-Spielstand (vor Version 1) als Version-1-Daten.
func _from_legacy_cfg() -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(LEGACY_CFG_PATH) != OK:
		return {}
	var data: Dictionary = {"version": 1, "options": {}, "progress": {}, "stats": {}}
	for key: String in cfg.get_section_keys("options") if cfg.has_section("options") else PackedStringArray():
		data["options"][key] = cfg.get_value("options", key)
	if cfg.has_section("progress"):
		for key: String in cfg.get_section_keys("progress"):
			var value: Variant = cfg.get_value("progress", key)
			if key == "characters":
				data["progress"]["characters"] = Array(value)
			elif key == STAT_TOTAL_SPARKS:
				data["stats"][STAT_TOTAL_SPARKS] = value
			else:
				data["progress"][key] = value
	return data


# --- Optionen ---

func get_option(key: String, default: Variant = null) -> Variant:
	return _data["options"].get(key, default)


func set_option(key: String, value: Variant) -> void:
	_data["options"][key] = value


func apply_options() -> void:
	TranslationServer.set_locale(get_option(LOCALE_KEY, DEFAULT_LOCALE))
	for bus_name: String in VOLUME_KEYS:
		_apply_volume(bus_name, get_volume(bus_name))
	if DisplayServer.get_name() != "headless":
		var fullscreen: bool = get_option(FULLSCREEN_KEY, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func get_volume(bus_name: String) -> float:
	return get_option(VOLUME_KEYS[bus_name], DEFAULT_VOLUME)


func set_volume(bus_name: String, linear: float) -> void:
	set_option(VOLUME_KEYS[bus_name], linear)
	_apply_volume(bus_name, linear)


## Barrierefreiheits-Faktor (0,25-1,0) für Gegner-HP, -Schaden oder -Tempo.
func get_assist_factor(key: String) -> float:
	return clampf(float(get_option(key, ASSIST_MAX_PCT)), ASSIST_MIN_PCT, ASSIST_MAX_PCT) / ASSIST_MAX_PCT


func _apply_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, MIN_LINEAR_VOLUME)))
		AudioServer.set_bus_mute(index, linear <= 0.0)


# --- Freischaltungen ---

func is_character_unlocked(character_id: StringName) -> bool:
	return String(character_id) in _data["progress"]["characters"]


func unlock_character(character_id: StringName) -> void:
	_add_unique(_data["progress"]["characters"], String(character_id))


func is_item_unlocked(item_id: StringName) -> bool:
	return String(item_id) in _data["progress"]["items"]


func unlock_item(item_id: StringName) -> void:
	_add_unique(_data["progress"]["items"], String(item_id))


func is_challenge_completed(challenge_id: StringName) -> bool:
	return String(challenge_id) in _data["progress"]["challenges"]


func complete_challenge(challenge_id: StringName) -> void:
	_add_unique(_data["progress"]["challenges"], String(challenge_id))


## Bestwert einer Run-Bedingung (Fortschrittsanzeige, z. B. "312/500 Kills").
func get_challenge_best(challenge_id: StringName) -> float:
	return float(_data["progress"]["challenge_best"].get(String(challenge_id), 0.0))


func record_challenge_best(challenge_id: StringName, value: float) -> void:
	if value > get_challenge_best(challenge_id):
		_data["progress"]["challenge_best"][String(challenge_id)] = value


## Merkt sich, auf welcher Spannungsstufe mit einem Charakter gewonnen wurde.
func record_win(character_id: StringName, difficulty: int) -> void:
	var won: Dictionary = _data["progress"]["won_difficulties"]
	var levels: Array = won.get(String(character_id), [])
	if difficulty not in levels:
		levels.append(difficulty)
		levels.sort()
	won[String(character_id)] = levels
	add_stat(STAT_WINS, 1)


func get_won_difficulties(character_id: StringName) -> Array[int]:
	var result: Array[int] = []
	for level: Variant in _data["progress"]["won_difficulties"].get(String(character_id), []):
		result.append(int(level))
	return result


func get_wins(character_id: StringName) -> int:
	return get_won_difficulties(character_id).size()


# --- Statistiken ---

func get_stat(key: String) -> int:
	return int(_data["stats"].get(key, 0))


func add_stat(key: String, amount: int) -> void:
	_data["stats"][key] = get_stat(key) + amount


func get_total_sparks() -> int:
	return get_stat(STAT_TOTAL_SPARKS)


static func weapon_kills_key(weapon_id: StringName) -> String:
	return WEAPON_KILLS_PREFIX + String(weapon_id)


# --- Unterbrochener Run ---

func has_run() -> bool:
	return not _data["run"].is_empty()


func save_run(run: Dictionary) -> void:
	_data["run"] = run
	save_game()


func load_run() -> Dictionary:
	return _data["run"].duplicate(true)


func clear_run() -> void:
	_data["run"] = {}
	save_game()


func _add_unique(list: Array, value: String) -> void:
	if value not in list:
		list.append(value)
