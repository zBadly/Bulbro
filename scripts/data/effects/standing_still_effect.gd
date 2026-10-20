class_name StandingStillEffect
extends ItemEffect
## Stat-Änderung, solange der Spieler stillsteht (Blitzlicht: -100 Rüstung).

@export var modifier: StatModifier


func apply(player: Player) -> void:
	player.standing_still_modifiers.append(modifier)


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_STANDING_STILL") % TextFormat.modifier_line(modifier)]
