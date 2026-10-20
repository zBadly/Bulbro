class_name ExplosionAction
extends EffectAction
## Explosion am Ereignisort (z. B. Supernova). Größe und Schaden skalieren mit den Explosions-Stats.

@export var radius: float = 0.0
@export var base_damage: float = 0.0
@export var scalings: Dictionary[StringName, float] = {}


func execute(ctx: EffectContext, origin: Vector2) -> void:
	var amount: int = ctx.effect_damage(base_damage, scalings)
	Hits.explode(ctx.tree, ctx.player, origin, radius, DamageInfo.create(amount, false, 0.0, null))


func describe() -> String:
	return TextFormat.t("ACTION_EXPLOSION") % damage_text(base_damage, scalings)
