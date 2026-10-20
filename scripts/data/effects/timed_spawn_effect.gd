class_name TimedSpawnEffect
extends ItemEffect
## Löst während einer Welle alle `interval` Sekunden eine Aktion aus (z. B. Ladestation).

@export var interval: float = 0.0
@export var action: EffectAction


func is_trigger() -> bool:
	return true


func on_wave_tick(ctx: EffectContext, entry: TriggerEntry, delta: float) -> void:
	entry.timer += delta
	while entry.timer >= interval:
		entry.timer -= interval
		action.execute(ctx, ctx.player.get_center())


func describe() -> PackedStringArray:
	return [TextFormat.t("TRIGGER_TIMED") % [TextFormat.number(interval), action.describe()]]
