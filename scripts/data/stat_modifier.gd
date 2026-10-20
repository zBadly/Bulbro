class_name StatModifier
extends Resource
## Eine Änderung an genau einem Stat. Items, Upgrades und Charaktere bestehen aus Listen davon.

enum Kind {
	FLAT, ## Addiert value zum Stat (z. B. +3 Max HP, +5 % Tempo als 5 Punkte "speed").
	PERCENT, ## Multipliziert den Stat-Endwert mit (1 + value/100).
	GAIN_PERCENT, ## "X-Modifikationen +value %": skaliert alle FLAT-Modifikatoren dieses Stats.
}

@export var stat: StringName
@export var kind: Kind = Kind.FLAT
@export var value: float = 0.0


static func create(p_stat: StringName, p_value: float, p_kind: Kind = Kind.FLAT) -> StatModifier:
	var mod: StatModifier = StatModifier.new()
	mod.stat = p_stat
	mod.value = p_value
	mod.kind = p_kind
	return mod
