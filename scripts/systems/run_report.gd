class_name RunReport
extends RefCounted
## Auswertung eines Runs für den Statistik-Reiter am Run-Ende (Phase 15, Paket 5).
## Liest nur die vorhandenen Werte aus RunStats (source_kills, source_damage, first_hit_time), zählt nichts neu.

const CONFIG: RunStatsConfig = preload("res://data/config/run_stats_config.tres")
const STRUCTURE_PATH: String = "res://data/structures/%s.tres"
const SECONDS_PER_MINUTE: int = 60
const DIGIT_GROUP: int = 3
## Ab diesem DPS-Wert ohne Nachkommastelle.
const DPS_DECIMALS_BELOW: float = 100.0
const PERCENT_SUFFIX: String = " %"
## Anzeigereihenfolge der Arten (Sortierung nach Art).
const KIND_ORDER: Array[String] = [
	DamageSource.WEAPON, DamageSource.ITEM, DamageSource.CHARACTER, DamageSource.ALLY, DamageSource.STRUCTURE]
const KIND_KEYS: Dictionary[String, String] = {
	DamageSource.WEAPON: "RUN_STATS_KIND_WEAPON",
	DamageSource.ITEM: "RUN_STATS_KIND_ITEM",
	DamageSource.CHARACTER: "RUN_STATS_KIND_CHARACTER",
	DamageSource.ALLY: "RUN_STATS_KIND_ALLY",
	DamageSource.STRUCTURE: "RUN_STATS_KIND_STRUCTURE",
}

## Sortierbare Spalten der Tabelle.
enum Column { NAME, KIND, KILLS, DAMAGE, SHARE, DPS }


## Eine Tabellenzeile: eine Herkunft mit ihren Werten.
class Row:
	var origin: StringName
	var kind: String
	var name: String
	var kills: int
	var damage: int
	## Anteil am Gesamtschaden (0-1).
	var share: float
	var dps: float


## Alle Herkünfte mit Kills oder Schaden, nach Schaden absteigend.
static func rows(run: RunStats) -> Array[Row]:
	var total: int = run.total_damage()
	var origins: Dictionary[StringName, bool] = {}
	for origin: StringName in run.source_damage:
		origins[origin] = true
	for origin: StringName in run.source_kills:
		origins[origin] = true
	var result: Array[Row] = []
	for origin: StringName in origins:
		var row: Row = Row.new()
		row.origin = origin
		row.kind = DamageSource.kind_of(origin)
		row.name = source_name(origin)
		row.kills = run.kills_of(origin)
		row.damage = run.damage_of(origin)
		row.share = float(row.damage) / total if total > 0 else 0.0
		row.dps = run.dps_of(origin, CONFIG.min_dps_time)
		result.append(row)
	sort_rows(result, Column.DAMAGE, true)
	return result


## Sortiert nach einer Spalte; bei Gleichstand nach Schaden, dann nach Name (stabile Reihenfolge).
static func sort_rows(list: Array[Row], column: Column, descending: bool) -> void:
	list.sort_custom(func(a: Row, b: Row) -> bool:
		var va: Variant = _value(a, column)
		var vb: Variant = _value(b, column)
		if va != vb:
			return (va > vb) if descending else (va < vb)
		if a.damage != b.damage:
			return a.damage > b.damage
		return a.name < b.name)


static func _value(row: Row, column: Column) -> Variant:
	match column:
		Column.NAME:
			return row.name.to_lower()
		Column.KIND:
			return KIND_ORDER.find(row.kind)
		Column.KILLS:
			return row.kills
		Column.SHARE:
			return row.share
		Column.DPS:
			return row.dps
	return row.damage


## Herkunft mit dem meisten Schaden (bei Gleichstand mehr Kills); leer ohne Schaden.
static func mvp(list: Array[Row]) -> StringName:
	var best: Row = null
	for row: Row in list:
		if row.damage <= 0:
			continue
		if best == null or row.damage > best.damage or (row.damage == best.damage and row.kills > best.kills):
			best = row
	return best.origin if best != null else &""


## Die stärksten Herkünfte nach Schaden (für die Run-Historie).
static func top_sources(run: RunStats, count: int) -> Array[Row]:
	var list: Array[Row] = rows(run)
	return list.slice(0, mini(count, list.size()))


static func kind_name(kind: String) -> String:
	return TextFormat.t(KIND_KEYS.get(kind, kind))


## Anzeigename einer Herkunft (Waffe, Item, Charakter, Verbündete, Struktur).
static func source_name(origin: StringName) -> String:
	var data: Resource = source_data(origin)
	if data != null and String(data.get("name_key")) != "":
		return TextFormat.t(data.get("name_key"))
	if DamageSource.kind_of(origin) == DamageSource.ALLY:
		return kind_name(DamageSource.ALLY)
	return String(DamageSource.id_of(origin))


## Icon einer Herkunft (null ohne passende Grafik, z. B. Verbündete).
static func source_icon(origin: StringName) -> Texture2D:
	var data: Resource = source_data(origin)
	if data is ItemData:
		return (data as ItemData).icon
	if data is CharacterData:
		return (data as CharacterData).get_portrait()
	if data != null:
		return data.get("texture") as Texture2D
	return null


static func source_data(origin: StringName) -> Resource:
	var id: String = String(DamageSource.id_of(origin))
	match DamageSource.kind_of(origin):
		DamageSource.WEAPON:
			return RunSave.find("weapons", id)
		DamageSource.ITEM:
			return RunSave.find("items", id)
		DamageSource.CHARACTER:
			return RunSave.find(Unlocks.CHARACTER_CATEGORY, id)
		DamageSource.STRUCTURE:
			var path: String = STRUCTURE_PATH % id
			return load(path) if ResourceLoader.exists(path) else null
	return null


## Zeit als "m:ss".
static func format_time(seconds: float) -> String:
	var total: int = roundi(seconds)
	return "%d:%02d" % [floori(float(total) / SECONDS_PER_MINUTE), total % SECONDS_PER_MINUTE]


## Ganzzahl mit Tausendertrennzeichen der Sprache ("12.345" bzw. "12,345").
static func format_int(value: int) -> String:
	var digits: String = str(absi(value))
	var groups: PackedStringArray = []
	while digits.length() > DIGIT_GROUP:
		groups.insert(0, digits.right(DIGIT_GROUP))
		digits = digits.left(digits.length() - DIGIT_GROUP)
	groups.insert(0, digits)
	return ("-" if value < 0 else "") + TextFormat.t("RUN_STATS_THOUSANDS").join(groups)


## Anteil (0-1) als "12,3 %" bzw. "12.3 %".
static func format_percent(share: float) -> String:
	return format_decimal(share * CombatMath.PERCENT) + PERCENT_SUFFIX


static func format_dps(dps: float) -> String:
	if dps >= DPS_DECIMALS_BELOW:
		return format_int(roundi(dps))
	return format_decimal(dps)


## Eine Nachkommastelle mit dem Dezimalzeichen der Sprache.
static func format_decimal(value: float) -> String:
	return ("%.1f" % value).replace(".", TextFormat.t("RUN_STATS_DECIMAL"))
