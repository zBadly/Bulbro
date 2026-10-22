class_name ExplosionAction
extends EffectAction
## Explosion am Ereignisort (z. B. Supernova). Größe und Schaden skalieren mit den Explosions-Stats.

@export var radius: float = 0.0
@export var base_damage: float = 0.0
@export var scalings: Dictionary[StringName, float] = {}
## Feuerball: fliegt mit diesem Tempo (px/s) vom Spieler zum Ort und explodiert erst dort. 0 = sofort.
@export var travel_speed: float = 0.0


func execute(ctx: EffectContext, origin: Vector2) -> void:
	var info: DamageInfo = ctx.damage_info(ctx.effect_damage(base_damage, scalings))
	var player: Player = ctx.player
	var tree: SceneTree = ctx.tree
	var explode: Callable = func() -> void:
		if is_instance_valid(player) and not player.is_dead:
			Hits.explode(tree, player, origin, radius, info)
	if travel_speed > 0.0 and is_instance_valid(player):
		Fx.fireball(tree, player.get_center(), origin, travel_speed, explode)
	else:
		explode.call()


func describe() -> String:
	return TextFormat.t("ACTION_EXPLOSION") % damage_text(base_damage, scalings)
