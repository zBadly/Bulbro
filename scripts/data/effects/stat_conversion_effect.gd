class_name StatConversionEffect
extends ItemEffect
## Leitet einen Stat aus einem anderen ab, live und abgerundet (Blitzlicht: +1 Nah pro 2 % Tempo,
## Panzerglas: +1 % Schaden pro Punkt Rüstung). `from_stat` darf auch eine Quelle sein (Stats.SOURCE_LEVEL,
## Stats.SOURCE_SPARKS). Negative Ausgangswerte zählen als 0.

@export var from_stat: StringName
@export var to_stat: StringName
## `gain` Punkte `to_stat` pro `per` Punkte `from_stat`.
@export var per: float = 1.0
@export var gain: float = 1.0
## Höchstens so viel `to_stat` (0 = ohne Grenze).
@export var max_gain: float = 0.0


func apply(player: Player) -> void:
	player.stats.add_conversion(from_stat, to_stat, per, gain, max_gain, player.applying_origin())


func describe() -> PackedStringArray:
	var line: String = TextFormat.t("EFFECT_CONVERSION") % [TextFormat.stat_value(to_stat, gain), TextFormat.t(Stats.label_key(to_stat)),
		TextFormat.stat_value(from_stat, per), TextFormat.t(Stats.label_key(from_stat))]
	if max_gain > 0.0:
		line += " " + TextFormat.t("EFFECT_CONVERSION_MAX") % TextFormat.stat_value(to_stat, max_gain)
	return [line]
