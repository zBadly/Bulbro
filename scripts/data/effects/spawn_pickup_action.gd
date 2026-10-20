class_name SpawnPickupAction
extends EffectAction
## Erzeugt Pickups in der Nähe des Spielers (z. B. Ladestation: Batterie).

## Entspricht Pickup.Kind (0 = Funke, 1 = Batterie, 2 = Karton).
@export_enum("Funke", "Batterie", "Karton") var kind: int = 1
@export var count: int = 1
@export var scatter: float = 0.0


func execute(ctx: EffectContext, _origin: Vector2) -> void:
	var pool: ObjectPool = Pools.get_pool(ctx.tree, Pools.PICKUPS)
	if pool == null:
		return
	var center: Vector2 = ctx.player.global_position
	for i in count:
		var offset: Vector2 = Vector2.from_angle(ctx.rng.randf() * TAU) * scatter
		(pool.acquire() as Pickup).drop(kind as Pickup.Kind, 1, center, center + offset, ctx.player)


func describe() -> String:
	return TextFormat.t("ACTION_SPAWN_PICKUP_%d" % kind)
