class_name ClassBonusEffect
extends ItemEffect
## Bonus auf einen Waffen-Stat nur für Waffen einer Klasse (z. B. +50 % Angriffstempo mit Unbewaffnet).

@export var weapon_class: StringName
@export var stat: StringName
@export var value: float = 0.0


func apply(player: Player) -> void:
	player.class_bonuses.append(self)


func describe() -> PackedStringArray:
	var amount: String = TextFormat.signed_number(value) + (" %" if stat in TextFormat.PERCENT_SUFFIX_STATS else "")
	return [TextFormat.t("EFFECT_CLASS_BONUS") % [TextFormat.colored(amount, value > 0.0),
		TextFormat.t(Stats.label_key(stat)), TextFormat.t(WeaponClasses.label_key(weapon_class))]]
