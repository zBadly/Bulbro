class_name MetaStats
extends RefCounted
## Gesamtstatistik über alle Runs (Phase 15, Paket 9): liest den Spielstand und liefert fertige Werte und
## Tabellenzeilen für den Statistik-Bildschirm. Admin-Runs fließen nie ein (Unlocks.evaluate_run_end).

const SECONDS_PER_MINUTE: int = 60
const MINUTES_PER_HOUR: int = 60
const DIFFICULTY_LEVELS: int = 6
const DASH: String = "–"
## Spannungsstufen im Reiter Charaktere: gewonnen grün, offen gedämpft.
const WON_COLOR: String = "#7ED957"
const OPEN_COLOR: String = "#5A5566"


## Kills mit einer Waffe: Herkunfts-Zähler seit Paket 9, ältere Stände nur mit dem Waffen-Zähler.
static func weapon_kills(weapon_id: StringName) -> int:
	return maxi(SaveManager.get_stat(SaveManager.weapon_kills_key(weapon_id)),
		SaveManager.get_stat(SaveManager.SOURCE_KILLS_PREFIX + String(DamageSource.weapon(weapon_id))))


## Kills eines Items: Schadenseffekte, Türme (Struktur gleichen Namens) und Begleiter.
static func item_kills(id: StringName) -> int:
	var total: int = 0
	for origin: StringName in [DamageSource.item(id), DamageSource.structure(id), DamageSource.pet(id)]:
		total += SaveManager.get_stat(SaveManager.SOURCE_KILLS_PREFIX + String(origin))
	return total


static func purchases(id: StringName) -> int:
	return SaveManager.get_stat(SaveManager.PURCHASES_PREFIX + String(id))


static func enemy_kills(enemy_id: StringName) -> int:
	return SaveManager.get_stat(SaveManager.ENEMY_KILLS_PREFIX + String(enemy_id))


static func character_runs(character_id: StringName) -> int:
	return SaveManager.get_stat(SaveManager.CHARACTER_RUNS_PREFIX + String(character_id))


## Meistgespielter Charakter (null, solange keiner gezählt ist).
static func favorite_character() -> CharacterData:
	var best: CharacterData = null
	var best_runs: int = 0
	for character: CharacterData in Unlocks.all_characters():
		var runs: int = character_runs(character.id)
		if runs > best_runs:
			best = character
			best_runs = runs
	return best


## Waffe mit den meisten Kills, insgesamt oder mit einem Charakter (null ohne Kills).
static func favorite_weapon(character_id: StringName = &"") -> WeaponData:
	var best: WeaponData = null
	var best_kills: int = 0
	for res: Resource in DataRegistry.get_all("weapons"):
		var weapon: WeaponData = res as WeaponData
		var kills: int = weapon_kills(weapon.id) if character_id == &"" \
			else SaveManager.get_stat(SaveManager.character_kills_key(character_id, weapon.id))
		if kills > best_kills:
			best = weapon
			best_kills = kills
	return best


## "12 h 05 min" bzw. "5 min".
static func format_play_time(seconds: int) -> String:
	var minutes: int = seconds / SECONDS_PER_MINUTE
	if minutes < MINUTES_PER_HOUR:
		return TextFormat.t("META_MINUTES") % minutes
	return TextFormat.t("META_HOURS_MINUTES") % [minutes / MINUTES_PER_HOUR, minutes % MINUTES_PER_HOUR]


## Unix-Zeit als lokales Datum mit Uhrzeit ("31.10.2026 14:05").
static func format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return DASH
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * SECONDS_PER_MINUTE
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time + bias)
	return TextFormat.t("META_DATE") % [dt["day"], dt["month"], dt["year"], dt["hour"], dt["minute"]]


static func _time_or_dash(seconds: float) -> String:
	return RunReport.format_time(seconds) if seconds > 0.0 else DASH


static func _name_or_dash(data: Resource) -> String:
	return TextFormat.t(data.get("name_key")) if data != null else DASH


## Reiter "Allgemein": Kennzahl und Wert.
static func general_rows() -> Array[PackedStringArray]:
	var runs: int = SaveManager.get_stat(SaveManager.STAT_RUNS)
	var wins: int = SaveManager.get_stat(SaveManager.STAT_WINS)
	var rate: String = RunReport.format_percent(float(wins) / runs) if runs > 0 else DASH
	var endless: int = SaveManager.get_endless_best_overall()
	var rows: Array[PackedStringArray] = [
		PackedStringArray([TextFormat.t("META_COL_STAT"), TextFormat.t("META_COL_VALUE")]),
		PackedStringArray([TextFormat.t("META_RUNS"), RunReport.format_int(runs)]),
		PackedStringArray([TextFormat.t("META_WINS"), "%s (%s)" % [RunReport.format_int(wins), rate]]),
		PackedStringArray([TextFormat.t("META_PLAY_TIME"), format_play_time(SaveManager.get_stat(SaveManager.STAT_PLAY_TIME))]),
		PackedStringArray([TextFormat.t("META_KILLS"), RunReport.format_int(SaveManager.get_stat(SaveManager.STAT_KILLS))]),
		PackedStringArray([TextFormat.t("META_ELITE_KILLS"), RunReport.format_int(SaveManager.get_stat(SaveManager.STAT_ELITE_KILLS))]),
		PackedStringArray([TextFormat.t("META_BOSS_KILLS"), RunReport.format_int(SaveManager.get_stat(SaveManager.STAT_BOSS_KILLS))]),
		PackedStringArray([TextFormat.t("META_SPARKS"), RunReport.format_int(SaveManager.get_stat(SaveManager.STAT_TOTAL_SPARKS))]),
		PackedStringArray([TextFormat.t("META_CRYSTALS"), RunReport.format_int(SaveManager.get_stat(SaveManager.STAT_CRYSTALS))]),
		PackedStringArray([TextFormat.t("META_BURN_KILLS"), RunReport.format_int(SaveManager.get_stat(SaveManager.STAT_BURN_KILLS))]),
		PackedStringArray([TextFormat.t("META_FAVORITE_CHARACTER"), _name_or_dash(favorite_character())]),
		PackedStringArray([TextFormat.t("META_FAVORITE_WEAPON"), _name_or_dash(favorite_weapon())]),
		PackedStringArray([TextFormat.t("META_ENDLESS_BEST"),
			TextFormat.t("RUN_STATS_ENDLESS_WAVE") % [endless, Lexicon.endless_wave(endless)] if endless > 0 else DASH]),
		PackedStringArray([TextFormat.t("META_ACHIEVEMENTS"),
			"%d/%d" % [Unlocks.completed_achievement_count(), Unlocks.all_achievements().size()]]),
	]
	return rows


## Bestzeiten: schnellster Sieg je Spannung (Kampfzeit) und schnellster Bosskill.
static func record_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = [PackedStringArray([TextFormat.t("META_COL_RECORD"), TextFormat.t("META_COL_TIME")])]
	for level: int in DIFFICULTY_LEVELS:
		rows.append(PackedStringArray([TextFormat.t("META_FASTEST_WIN") % level,
			_time_or_dash(SaveManager.get_record(SaveManager.RECORD_WIN_TIME % level))]))
	rows.append(PackedStringArray([TextFormat.t("META_FASTEST_BOSS"), _time_or_dash(SaveManager.get_record(SaveManager.RECORD_BOSS_KILL))]))
	return rows


## Reiter "Charaktere": Runs, Siege je Spannung, Endlos-Bestwert, Lieblingswaffe.
static func character_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = [PackedStringArray([TextFormat.t("META_COL_CHARACTER"), TextFormat.t("META_RUNS"),
		TextFormat.t("META_COL_WON_LEVELS"), TextFormat.t("META_ENDLESS_BEST"), TextFormat.t("META_FAVORITE_WEAPON")])]
	for character: CharacterData in Unlocks.all_characters():
		var title: String = TextFormat.t(character.name_key)
		if not Unlocks.is_unlocked(character):
			rows.append(PackedStringArray([title, TextFormat.t("META_LOCKED"), "", "", ""]))
			continue
		var levels: PackedStringArray = []
		var won: Array[int] = SaveManager.get_won_difficulties(character.id)
		for level: int in DIFFICULTY_LEVELS:
			levels.append("[color=%s]%d[/color]" % [WON_COLOR if level in won else OPEN_COLOR, level])
		var endless: int = SaveManager.get_endless_best(character.id)
		rows.append(PackedStringArray([title, RunReport.format_int(character_runs(character.id)), "  ".join(levels),
			TextFormat.t("RUN_STATS_ENDLESS_WAVE") % [endless, Lexicon.endless_wave(endless)] if endless > 0 else DASH,
			_name_or_dash(favorite_weapon(character.id))]))
	return rows


## Reiter "Waffen/Items": Name, Kills, Käufe; sortiert nach Kills. Items nur mit Kills oder Käufen.
static func weapon_rows() -> Array[PackedStringArray]:
	var list: Array[Array] = []
	for res: Resource in DataRegistry.get_all("weapons"):
		var weapon: WeaponData = res as WeaponData
		list.append([TextFormat.t(weapon.name_key), weapon_kills(weapon.id), purchases(weapon.id)])
	return _sorted_rows(TextFormat.t("META_COL_WEAPON"), list)


static func item_rows() -> Array[PackedStringArray]:
	var list: Array[Array] = []
	for category: String in ["items", "pets"]:
		for res: Resource in DataRegistry.get_all(category):
			var id: StringName = res.get("id")
			var kills: int = item_kills(id)
			var bought: int = purchases(id)
			if kills > 0 or bought > 0:
				list.append([TextFormat.t(res.get("name_key")), kills, bought])
	return _sorted_rows(TextFormat.t("META_COL_ITEM"), list)


static func _sorted_rows(title: String, list: Array[Array]) -> Array[PackedStringArray]:
	list.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1] > b[1] if a[1] != b[1] else (a[2] > b[2] if a[2] != b[2] else String(a[0]) < String(b[0])))
	var rows: Array[PackedStringArray] = [PackedStringArray([title, TextFormat.t("META_COL_KILLS"), TextFormat.t("META_COL_BOUGHT")])]
	for entry: Array in list:
		rows.append(PackedStringArray([entry[0], RunReport.format_int(entry[1]), RunReport.format_int(entry[2])]))
	if list.is_empty():
		rows.append(PackedStringArray([TextFormat.t("META_NONE"), "", ""]))
	return rows


## Reiter "Gegner": Kills je Typ (alle Typen, auch ohne Kills), sortiert nach Kills.
static func enemy_rows() -> Array[PackedStringArray]:
	var list: Array[Array] = []
	for res: Resource in DataRegistry.get_all("enemies"):
		var enemy: EnemyData = res as EnemyData
		var kind: int = Lexicon.EnemyKind.BOSS if enemy.is_boss else (Lexicon.EnemyKind.ELITE if enemy.is_elite else Lexicon.EnemyKind.NORMAL)
		list.append([TextFormat.t(enemy.name_key), enemy_kills(enemy.id), TextFormat.t(Lexicon.ENEMY_KIND_KEYS[kind])])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] if a[1] != b[1] else String(a[0]) < String(b[0]))
	var rows: Array[PackedStringArray] = [PackedStringArray([TextFormat.t("META_COL_ENEMY"), TextFormat.t("META_COL_KIND"),
		TextFormat.t("META_COL_KILLS")])]
	for entry: Array in list:
		rows.append(PackedStringArray([entry[0], entry[2], RunReport.format_int(entry[1])]))
	return rows


## Kurzzeile eines Eintrags der Run-Historie für die Liste.
static func history_title(entry: Dictionary) -> String:
	var character: Resource = RunSave.find(Unlocks.CHARACTER_CATEGORY, String(entry.get("character", "")))
	return TextFormat.t("META_HISTORY_LINE") % [format_date(int(entry.get("date", 0))), _name_or_dash(character),
		int(entry.get("difficulty", 0)), _result_text(entry), _wave_text(entry)]


static func _result_text(entry: Dictionary) -> String:
	return TextFormat.t("META_RESULT_VICTORY" if entry.get("result", "") == RunHistory.RESULT_VICTORY else "META_RESULT_DEFEAT")


static func _wave_text(entry: Dictionary) -> String:
	var endless: int = int(entry.get("endless_wave", 0))
	if endless > 0:
		return TextFormat.t("RUN_STATS_ENDLESS_WAVE") % [endless, int(entry.get("wave", 0))]
	return TextFormat.t("META_WAVE") % int(entry.get("wave", 0))


## Details eines Runs der Historie.
static func history_rows(entry: Dictionary) -> Array[PackedStringArray]:
	var character: Resource = RunSave.find(Unlocks.CHARACTER_CATEGORY, String(entry.get("character", "")))
	return [
		PackedStringArray([TextFormat.t("META_COL_STAT"), TextFormat.t("META_COL_VALUE")]),
		PackedStringArray([TextFormat.t("META_COL_DATE"), format_date(int(entry.get("date", 0)))]),
		PackedStringArray([TextFormat.t("META_COL_CHARACTER"), _name_or_dash(character)]),
		PackedStringArray([TextFormat.t("META_COL_DIFFICULTY"), str(int(entry.get("difficulty", 0)))]),
		PackedStringArray([TextFormat.t("META_COL_RESULT"), _result_text(entry)]),
		PackedStringArray([TextFormat.t("RUN_STATS_WAVE"), _wave_text(entry)]),
		PackedStringArray([TextFormat.t("RUN_STATS_BOSS_CYCLES"), str(int(entry.get("boss_cycles", 0)))]),
		PackedStringArray([TextFormat.t("RUN_STATS_TIME"), RunReport.format_time(float(entry.get("time", 0.0)))]),
		PackedStringArray([TextFormat.t("RUN_STATS_LEVEL"), str(int(entry.get("level", 0)))]),
		PackedStringArray([TextFormat.t("RUN_STATS_KILLS"), RunReport.format_int(int(entry.get("kills", 0)))]),
	]


## Die stärksten Quellen eines Runs der Historie (Name, Schaden, Kills).
static func history_source_rows(entry: Dictionary) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = [PackedStringArray([TextFormat.t("RUN_STATS_COL_SOURCE"),
		TextFormat.t("RUN_STATS_COL_DAMAGE"), TextFormat.t("RUN_STATS_COL_KILLS")])]
	for top: Variant in entry.get("top_sources", []):
		var source: Dictionary = top as Dictionary
		rows.append(PackedStringArray([RunReport.source_name(StringName(source.get("source", ""))),
			RunReport.format_int(int(source.get("damage", 0))), RunReport.format_int(int(source.get("kills", 0)))]))
	return rows
