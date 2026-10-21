class_name LifestealCapEffect
extends ItemEffect
## Ändert das Lebensraub-Limit (Vampirbirne: Faktor 0,5 auf den Mindestabstand = doppelt so viele Heilungen).

@export var interval_factor: float = 1.0


func apply(player: Player) -> void:
	player.lifesteal_interval_factor *= interval_factor


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_LIFESTEAL_CAP") % TextFormat.number(1.0 / interval_factor)]
