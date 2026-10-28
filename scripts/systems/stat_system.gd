class_name StatSystem
extends RefCounted
## Verrechnet Basiswerte mit Modifikatoren:
##   Endwert = (Basis + Summe(FLAT) x Zuwachs-Multiplikator) x (1 + Summe(PERCENT) / 100)
##   Zuwachs-Multiplikator = 1 + Summe(GAIN_PERCENT) / 100
## Der Zuwachs-Multiplikator ("X-Modifikationen +Y %") wirkt nur auf FLAT-Modifikatoren, nicht auf den Basiswert.

signal stats_changed

const PERCENT: float = 100.0
const ROUNDING_EPSILON: float = 0.000001

var _base: StatBlock = StatBlock.new()
var _modifiers: Array[StatModifier] = []
var _cache: Dictionary[StringName, float] = {}
## Abgeleitete Stats: to += floor(from / per) x gain, höchstens max_gain (0 = ohne Grenze).
## `from` darf selbst nicht abgeleitet sein; es ist ein Stat oder eine Quelle aus `_sources` (Level, Funken).
var _conversions: Array[Dictionary] = []
## Werte außerhalb der Stats, aus denen Umrechnungen ableiten können (Stats.SOURCE_LEVEL, Stats.SOURCE_SPARKS).
var _sources: Dictionary[StringName, float] = {}
var _owns_base: bool = false


func _init(base: StatBlock = null) -> void:
	if base != null:
		_base = base


func set_base(base: StatBlock) -> void:
	_base = base
	_changed()


func add_modifier(mod: StatModifier) -> void:
	_modifiers.append(mod)
	_changed()


func add_modifiers(mods: Array[StatModifier]) -> void:
	_modifiers.append_array(mods)
	_changed()


func remove_modifier(mod: StatModifier) -> bool:
	var index: int = _modifiers.find(mod)
	if index < 0:
		return false
	_modifiers.remove_at(index)
	_changed()
	return true


func remove_modifiers(mods: Array[StatModifier]) -> void:
	for mod: StatModifier in mods:
		var index: int = _modifiers.find(mod)
		if index >= 0:
			_modifiers.remove_at(index)
	_changed()


## Erhöht einen Basiswert (z. B. Startboni eines Charakters, die nicht als "Zuwachs" zählen).
## Die geteilte Basis-Resource wird dabei kopiert, nie verändert.
func add_base_value(stat: StringName, value: float) -> void:
	if not _owns_base:
		_base = _base.duplicate(true)
		_owns_base = true
	_base.values[stat] = _base.get_value(stat) + value
	_changed()


## `origin` (DamageSource-Herkunft) erscheint im Stat-Tooltip ("+12 % Schaden durch Panzerglas").
func add_conversion(from_stat: StringName, to_stat: StringName, per: float, gain: float, max_gain: float = 0.0,
		origin: StringName = &"") -> void:
	_conversions.append({"from": from_stat, "to": to_stat, "per": per, "gain": gain, "max": max_gain, "origin": origin})
	_changed()


## Setzt eine Quelle (Level, Funken im Besitz). Nur wenn eine Umrechnung sie nutzt, ändern sich Stats.
func set_source(source: StringName, value: float) -> void:
	if is_equal_approx(_sources.get(source, 0.0), value):
		return
	_sources[source] = value
	for conversion: Dictionary in _conversions:
		if conversion["from"] == source:
			_changed()
			return


func get_source(source: StringName) -> float:
	return _sources.get(source, 0.0)


## Beiträge der Umrechnungen zu `stat`: je Eintrag {"origin", "from", "value"} (nur Beiträge ungleich 0).
func get_conversion_parts(stat: StringName) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	for conversion: Dictionary in _conversions:
		if conversion["to"] != stat:
			continue
		var value: float = _conversion_value(conversion)
		if not is_zero_approx(value):
			parts.append({"origin": conversion["origin"], "from": conversion["from"], "value": value})
	return parts


func clear_modifiers() -> void:
	_modifiers.clear()
	_changed()


func get_stat(stat: StringName) -> float:
	if not _cache.has(stat):
		_cache[stat] = _compute(stat)
	return _cache[stat]


## Wert des Stats, als wären `extra` zusätzlich aktiv (Vorschau im Shop, ohne Zustand zu ändern).
func get_stat_with(stat: StringName, extra: Array[StatModifier]) -> float:
	_modifiers.append_array(extra)
	var value: float = _compute(stat)
	_modifiers.resize(_modifiers.size() - extra.size())
	return value


func get_gain_multiplier(stat: StringName) -> float:
	var gain: float = 0.0
	for mod: StatModifier in _modifiers:
		if mod.stat == stat and mod.kind == StatModifier.Kind.GAIN_PERCENT:
			gain += mod.value
	return 1.0 + gain / PERCENT


func _compute(stat: StringName) -> float:
	var flat: float = 0.0
	var percent: float = 0.0
	for mod: StatModifier in _modifiers:
		if mod.stat != stat:
			continue
		match mod.kind:
			StatModifier.Kind.FLAT:
				flat += mod.value
			StatModifier.Kind.PERCENT:
				percent += mod.value
	var value: float = (_base.get_value(stat) + flat * get_gain_multiplier(stat)) * (1.0 + percent / PERCENT)
	for conversion: Dictionary in _conversions:
		if conversion["to"] == stat:
			value += _conversion_value(conversion)
	return value


func _conversion_value(conversion: Dictionary) -> float:
	var from: StringName = conversion["from"]
	var amount: float = _sources[from] if _sources.has(from) else get_stat(from)
	# Kleiner Zuschlag gegen Rundungsfehler (9 Tempo / 3 = 2,9999... soll 3 ergeben).
	var value: float = floorf(maxf(0.0, amount) / conversion["per"] + ROUNDING_EPSILON) * conversion["gain"]
	return minf(value, conversion["max"]) if conversion["max"] > 0.0 else value


func _changed() -> void:
	_cache.clear()
	stats_changed.emit()
