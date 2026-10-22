class_name OverhealDamageEffect
extends ItemEffect
## Heilung über Max HP wird zu Schaden am nächsten Gegner (Vampirbirne). Bruchteile werden gesammelt.

const POOL_KEY: String = "pool"

@export var damage_per_hp: float = 1.0


func is_trigger() -> bool:
	return true


func on_overheal(ctx: EffectContext, entry: TriggerEntry, amount: float) -> void:
	var pool: float = float(entry.state.get(POOL_KEY, 0.0)) + amount * damage_per_hp
	var whole: int = floori(pool)
	if whole >= CombatMath.MIN_DAMAGE:
		var target: Damageable = _nearest_enemy(ctx)
		if target != null:
			Fx.lightning(ctx.tree, ctx.player.get_center(), target.get_hit_position())
			target.take_damage(ctx.damage_info(whole))
			pool -= whole
	entry.state[POOL_KEY] = pool


func _nearest_enemy(ctx: EffectContext) -> Damageable:
	var best: Damageable = null
	var best_dist: float = INF
	var origin: Vector2 = ctx.player.global_position
	for target: Damageable in Hits.alive_targets(ctx.tree):
		var dist: float = origin.distance_squared_to(target.global_position)
		if dist < best_dist:
			best = target
			best_dist = dist
	return best


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_OVERHEAL")]
