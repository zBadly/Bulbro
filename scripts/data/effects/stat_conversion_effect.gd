class_name StatConversionEffect
extends ItemEffect
## Leitet einen Stat aus einem anderen ab (Blitzlicht: +1 Nah pro 2 % Tempo, abgerundet).

@export var from_stat: StringName
@export var to_stat: StringName
## `gain` Punkte `to_stat` pro `per` Punkte `from_stat`.
@export var per: float = 1.0
@export var gain: float = 1.0


func apply(player: Player) -> void:
	player.stats.add_conversion(from_stat, to_stat, gain / per)


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_CONVERSION") % [TextFormat.number(gain), TextFormat.t(Stats.label_key(to_stat)),
		TextFormat.stat_value(from_stat, per), TextFormat.t(Stats.label_key(from_stat))]]
