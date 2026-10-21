class_name FrostNovaAction
extends EffectAction
## Frostnova: Schaden im Radius und Verlangsamung um `slow_pct` % für `duration` Sekunden.

@export var radius: float = 0.0
@export var base_damage: float = 0.0
@export var scalings: Dictionary[StringName, float] = {}
@export var slow_pct: float = 0.0
@export var duration: float = 0.0


func execute(ctx: EffectContext, origin: Vector2) -> void:
	Fx.frost_nova(ctx.tree, origin, radius)
	var amount: int = ctx.effect_damage(base_damage, scalings) if base_damage > 0.0 or not scalings.is_empty() else 0
	for target: Damageable in Hits.alive_targets(ctx.tree):
		if origin.distance_to(target.get_hit_position()) > radius:
			continue
		var enemy: Enemy = target as Enemy
		if enemy != null:
			enemy.apply_slow(1.0 - slow_pct / CombatMath.PERCENT, duration)
		if amount > 0:
			target.take_damage(DamageInfo.create(amount, false, 0.0, null))


func describe() -> String:
	return TextFormat.t("ACTION_FROST_NOVA") % [damage_text(base_damage, scalings), roundi(slow_pct), TextFormat.number(duration)]
