class_name Pools
extends RefCounted
## Zugriff auf die Object Pools der aktuellen Szene über Gruppen.

const PLAYER_PROJECTILES: StringName = &"pool_player_projectiles"
const DAMAGE_NUMBERS: StringName = &"pool_damage_numbers"
const ENEMY_PROJECTILES: StringName = &"pool_enemy_projectiles"
const SPAWN_MARKERS: StringName = &"pool_spawn_markers"
const PICKUPS: StringName = &"pool_pickups"
const ALLIES: StringName = &"pool_allies"


static func get_pool(tree: SceneTree, group: StringName) -> ObjectPool:
	return tree.get_first_node_in_group(group) as ObjectPool


static func spawn_damage_number(tree: SceneTree, amount: int, is_crit: bool, world_position: Vector2) -> void:
	var pool: ObjectPool = get_pool(tree, DAMAGE_NUMBERS)
	if pool == null:
		return
	var number: DamageNumber = pool.acquire() as DamageNumber
	number.show_damage(amount, is_crit, world_position)


## Freier Text über einer Position (z. B. "Gerettet!" der Reservebatterie).
static func spawn_text(tree: SceneTree, text: String, color: Color, font_size: int, world_position: Vector2) -> void:
	var pool: ObjectPool = get_pool(tree, DAMAGE_NUMBERS)
	if pool == null:
		return
	(pool.acquire() as DamageNumber).show_text(text, color, font_size, world_position)


## Graues "Immun" statt einer Schadenszahl (Elite/Boss kurz nach dem Phasenwechsel).
static func spawn_immune_text(tree: SceneTree, world_position: Vector2) -> void:
	var pool: ObjectPool = get_pool(tree, DAMAGE_NUMBERS)
	if pool == null:
		return
	(pool.acquire() as DamageNumber).show_immune(world_position)
