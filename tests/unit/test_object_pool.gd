extends GutTest
## Tests für ObjectPool.

const NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")


func _pool() -> ObjectPool:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = NUMBER_SCENE
	add_child_autofree(pool)
	return pool


func test_prewarm_creates_free_instances() -> void:
	var pool: ObjectPool = _pool()
	pool.prewarm(5)
	assert_eq(pool.free_count(), 5)
	assert_eq(pool.get_child_count(), 5)


func test_acquire_reuses_released_instance() -> void:
	var pool: ObjectPool = _pool()
	pool.prewarm(1)
	var first: Node = pool.acquire()
	pool.release(first)
	assert_same(pool.acquire(), first)
	assert_eq(pool.get_child_count(), 1)


func test_acquire_grows_when_empty() -> void:
	var pool: ObjectPool = _pool()
	pool.acquire()
	pool.acquire()
	assert_eq(pool.get_child_count(), 2)


func test_released_node_is_hidden_and_disabled() -> void:
	var pool: ObjectPool = _pool()
	var node: CanvasItem = pool.acquire() as CanvasItem
	pool.release(node)
	assert_false(node.visible)
	assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED)


func test_double_release_is_ignored() -> void:
	var pool: ObjectPool = _pool()
	var node: Node = pool.acquire()
	pool.release(node)
	pool.release(node)
	assert_eq(pool.free_count(), 1)


func test_pool_property_is_set() -> void:
	var pool: ObjectPool = _pool()
	var number: DamageNumber = pool.acquire() as DamageNumber
	assert_same(number.pool, pool)
