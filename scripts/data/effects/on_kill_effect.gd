class_name OnKillEffect
extends ItemEffect
## Mit `chance` bei jedem Gegnertod: Aktion am Ort des Gegners.

@export_range(0.0, 1.0) var chance: float = 0.0
@export var action: EffectAction


func is_trigger() -> bool:
	return true


func on_enemy_killed(ctx: EffectContext, _entry: TriggerEntry, position: Vector2) -> void:
	if ctx.rng.randf() < chance:
		action.execute(ctx, position)


func describe() -> PackedStringArray:
	return [TextFormat.t("TRIGGER_ON_KILL") % [roundi(chance * 100.0), action.describe()]]
