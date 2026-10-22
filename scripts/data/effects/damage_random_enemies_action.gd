class_name DamageRandomEnemiesAction
extends EffectAction
## Trifft zufällige lebende Gegner (z. B. Tesla-Spule, Blitzableiter) mit Blitz-Effekt.

@export var count: int = 1
@export var base_damage: float = 0.0
@export var scalings: Dictionary[StringName, float] = {}


func execute(ctx: EffectContext, origin: Vector2) -> void:
	var amount: int = ctx.effect_damage(base_damage, scalings)
	for enemy: Damageable in Hits.random_enemies(ctx.tree, count, ctx.rng):
		Fx.lightning(ctx.tree, origin, enemy.get_hit_position())
		enemy.take_damage(ctx.damage_info(amount))


func describe() -> String:
	return TextFormat.t("ACTION_DAMAGE_RANDOM") % [damage_text(base_damage, scalings), count]
