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
	return (_base.get_value(stat) + flat * get_gain_multiplier(stat)) * (1.0 + percent / PERCENT)


func _changed() -> void:
	_cache.clear()
	stats_changed.emit()
