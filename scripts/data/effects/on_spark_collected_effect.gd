class_name OnSparkCollectedEffect
extends ItemEffect
## Mit `chance` beim Aufsammeln eines Funkens: Aktion am Spieler (z. B. Discokugel).

@export_range(0.0, 1.0) var chance: float = 0.0
@export var action: EffectAction


func is_trigger() -> bool:
	return true


func on_spark_collected(ctx: EffectContext, _entry: TriggerEntry) -> void:
	if ctx.rng.randf() < chance:
		action.execute(ctx, ctx.player.get_center())


func describe() -> PackedStringArray:
	return [TextFormat.t("TRIGGER_ON_SPARK") % [roundi(chance * 100.0), action.describe()]]
