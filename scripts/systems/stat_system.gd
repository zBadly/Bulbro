class_name StatSystem
extends RefCounted
## Verrechnet Basiswerte mit Modifikatoren:
##   Endwert = (Basis + Summe(FLAT) x Zuwachs-Multiplikator) x (1 + Summe(PERCENT) / 100)
##   Zuwachs-Multiplikator = 1 + Summe(GAIN_PERCENT) / 100
## Der Zuwachs-Multiplikator ("X-Modifikationen +Y %") wirkt nur auf FLAT-Modifikatoren, nicht auf den Basiswert.

signal stats_changed

const PERCENT: float = 100.0

var _base: StatBlock = StatBlock.new()
var _modifiers: Array[StatModifier] = []
var _cache: Dictionary[StringName, float] = {}
## Abgeleitete Stats: to += floor(from x ratio). `from` darf selbst nicht abgeleitet sein.
var _conversions: Array[Dictionary] = []
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


func add_conversion(from_stat: StringName, to_stat: StringName, ratio: float) -> void:
	_conversions.append({"from": from_stat, "to": to_stat, "ratio": ratio})
	_changed()


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
			value += floorf(maxf(0.0, get_stat(conversion["from"])) * conversion["ratio"])
	return value


func _changed() -> void:
	_cache.clear()
	stats_changed.emit()
