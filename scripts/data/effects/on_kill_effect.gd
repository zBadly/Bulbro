class_name OnKillEffect
extends ItemEffect
## Mit `chance` bei jedem Gegnertod: Aktion am Ort des Gegners.
## Mit `only_burning` nur, wenn der Gegner beim Tod brannte (Zündkerze: kleine Explosion).

@export_range(0.0, 1.0) var chance: float = 0.0
@export var action: EffectAction
@export var only_burning: bool = false


func is_trigger() -> bool:
	return true


func on_enemy_killed(ctx: EffectContext, _entry: TriggerEntry, position: Vector2, _data: EnemyData, _info: DamageInfo) -> void:
	if not only_burning and ctx.rng.randf() < chance:
		action.execute(ctx, position)


func on_burning_enemy_killed(ctx: EffectContext, _entry: TriggerEntry, position: Vector2) -> void:
	if only_burning and ctx.rng.randf() < chance:
		action.execute.call_deferred(ctx, position)


func describe() -> PackedStringArray:
	var key: String = "TRIGGER_ON_BURNING_KILL" if only_burning else "TRIGGER_ON_KILL"
	return [TextFormat.t(key) % [roundi(chance * 100.0), action.describe()]]
