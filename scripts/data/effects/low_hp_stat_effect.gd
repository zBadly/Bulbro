class_name LowHpStatEffect
extends ItemEffect
## Stat-Änderungen, solange die HP unter einem Anteil der Max HP liegen (Thermosicherung: unter 30 % HP
## +40 % Angriffstempo und +20 % Tempo). Der Spieler schaltet sie bei jeder HP-Änderung an oder ab.

@export_range(0.0, 100.0) var hp_below_pct: float = 0.0
@export var modifiers: Array[StatModifier] = []


func apply(player: Player) -> void:
	player.low_hp_effects.append(self)
	player.update_low_hp()


func describe() -> PackedStringArray:
	var parts: PackedStringArray = []
	for mod: StatModifier in modifiers:
		parts.append(TextFormat.modifier_line(mod))
	return [TextFormat.t("EFFECT_LOW_HP") % [TextFormat.number(hp_below_pct), ", ".join(parts)]]
