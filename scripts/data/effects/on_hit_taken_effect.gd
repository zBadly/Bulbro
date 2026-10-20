class_name OnHitTakenEffect
extends ItemEffect
## Mit `chance` bei jedem erlittenen Treffer: Aktion am Spieler.

@export_range(0.0, 1.0) var chance: float = 0.0
@export var action: EffectAction


func is_trigger() -> bool:
	return true


func on_hit_taken(ctx: EffectContext, _entry: TriggerEntry) -> void:
	if ctx.rng.randf() < chance:
		action.execute(ctx, ctx.player.get_center())


func describe() -> PackedStringArray:
	return [TextFormat.t("TRIGGER_ON_HIT") % [roundi(chance * 100.0), action.describe()]]
