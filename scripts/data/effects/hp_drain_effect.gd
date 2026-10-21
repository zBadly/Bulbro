class_name HpDrainEffect
extends ItemEffect
## Verliert während einer Welle alle `interval` Sekunden `amount` HP, nie unter `min_hp` (Vampirbirne).

@export var amount: float = 0.0
@export var interval: float = 0.0
@export var min_hp: float = 1.0


func is_trigger() -> bool:
	return true


func on_wave_tick(ctx: EffectContext, entry: TriggerEntry, delta: float) -> void:
	entry.timer += delta
	while entry.timer >= interval:
		entry.timer -= interval
		ctx.player.drain_hp(amount, min_hp)


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_HP_DRAIN") % [TextFormat.number(amount), TextFormat.number(interval)]]
