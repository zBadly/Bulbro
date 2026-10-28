class_name PetBlockBehavior
extends PetBehavior
## Lampenschirm-Schildkröte: blockt mit eigener Abklingzeit das nächste gegnerische Projektil in der Nähe des Spielers.
## Die Schildkröte duckt sich beim Blocken unter ihren Schirm.

const COOLDOWN_KEY: String = "cooldown"

@export var block_color: Color = Color.WHITE


func tick(pet: Pet, delta: float) -> bool:
	var left: float = float(pet.state.get(COOLDOWN_KEY, 0.0)) - delta
	pet.state[COOLDOWN_KEY] = left
	if left > 0.0:
		return false
	var stats: PetTierStats = pet.get_tier_stats()
	var projectile: EnemyProjectile = nearest_projectile(pet.get_tree(), pet.player.get_center(), stats.radius)
	if projectile == null:
		return false
	pet.state[COOLDOWN_KEY] = stats.cooldown
	var at: Vector2 = projectile.global_position
	projectile.block()
	Fx.pulse(pet.get_tree(), at, Pet.CONFIG.contact_distance, block_color)
	Fx.particles(pet.get_tree(), ParticleFx.Kind.HIT, at)
	Juice.duck(pet.visual)
	Juice.effect_flash(pet.sprite)
	GameState.run_stats.record_pet_event(pet.get_origin(), 1)
	return false


## Nächstes fliegendes Gegnerprojektil im Radius um `center`, sonst null.
static func nearest_projectile(tree: SceneTree, center: Vector2, radius: float) -> EnemyProjectile:
	var pool: ObjectPool = Pools.get_pool(tree, Pools.ENEMY_PROJECTILES)
	if pool == null:
		return null
	var best: EnemyProjectile = null
	var best_dist: float = radius * radius
	for node: Node in pool.get_active():
		var projectile: EnemyProjectile = node as EnemyProjectile
		if projectile == null or not projectile.is_active():
			continue
		var dist: float = center.distance_squared_to(projectile.global_position)
		if dist <= best_dist:
			best = projectile
			best_dist = dist
	return best


func describe(stats: PetTierStats) -> PackedStringArray:
	return [TextFormat.t("PET_BLOCK_DESC") % [seconds(stats.cooldown), TextFormat.number(stats.radius)]]


func status_lines(pet: Pet) -> PackedStringArray:
	return [TextFormat.t("TIP_PET_BLOCKED") % GameState.run_stats.pet_events_of(pet.get_origin())]
