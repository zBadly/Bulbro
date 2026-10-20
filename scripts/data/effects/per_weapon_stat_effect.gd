class_name PerWeaponStatEffect
extends ItemEffect
## Stat-Änderung pro getragener Waffe (Lichterkette: -5 % Schaden pro Waffe).

@export var stat: StringName
@export var value_per_weapon: float = 0.0


func apply(player: Player) -> void:
	player.per_weapon_effects.append(self)
	player.update_weapon_modifiers()


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_PER_WEAPON") % TextFormat.modifier_line(StatModifier.create(stat, value_per_weapon))]
