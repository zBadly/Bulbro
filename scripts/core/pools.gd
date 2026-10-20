class_name Pools
extends RefCounted
## Zugriff auf die Object Pools der aktuellen Szene über Gruppen.

const PLAYER_PROJECTILES: StringName = &"pool_player_projectiles"
const DAMAGE_NUMBERS: StringName = &"pool_damage_numbers"


static func get_pool(tree: SceneTree, group: StringName) -> ObjectPool:
	return tree.get_first_node_in_group(group) as ObjectPool


static func spawn_damage_number(tree: SceneTree, amount: int, is_crit: bool, world_position: Vector2) -> void:
	var pool: ObjectPool = get_pool(tree, DAMAGE_NUMBERS)
	if pool == null:
		return
	var number: DamageNumber = pool.acquire() as DamageNumber
	number.show_damage(amount, is_crit, world_position)
