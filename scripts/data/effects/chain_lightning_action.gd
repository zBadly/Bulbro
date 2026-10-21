class_name ChainLightningAction
extends EffectAction
## Kettenblitz: trifft das Ziel am Ereignisort und springt `jumps`-mal auf das jeweils nächste Ziel.

@export var jumps: int = 0
@export var jump_range: float = 0.0
@export var base_damage: float = 0.0
@export var scalings: Dictionary[StringName, float] = {}


func execute(ctx: EffectContext, origin: Vector2) -> void:
	var amount: int = ctx.effect_damage(base_damage, scalings)
	var hit: Dictionary[int, bool] = {}
	var from: Vector2 = origin
	for i in jumps + 1:
		var target: Damageable = Hits.nearest_target(ctx.tree, from, jump_range, hit)
		if target == null:
			return
		hit[target.get_instance_id()] = true
		var to: Vector2 = target.get_hit_position()
		if i > 0:
			Fx.lightning(ctx.tree, from, to)
		Fx.zap(ctx.tree, to)
		target.take_damage(DamageInfo.create(amount, false, 0.0, null))
		from = to


func describe() -> String:
	return TextFormat.t("ACTION_CHAIN_LIGHTNING") % [damage_text(base_damage, scalings), jumps]
