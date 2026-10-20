extends GutTest
## Prüft die Endzustände der Juice-Tweens.


func _make_node() -> Node2D:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	return node


func test_spawn_pop_ends_at_base_scale() -> void:
	var node: Node2D = _make_node()
	await Juice.spawn_pop(node).finished
	assert_almost_eq(node.scale, Vector2.ONE, Vector2(0.001, 0.001))


func test_squash_pop_ends_at_zero() -> void:
	var node: Node2D = _make_node()
	await Juice.squash_pop(node).finished
	assert_almost_eq(node.scale, Vector2.ZERO, Vector2(0.001, 0.001))


func test_walk_tilt_leans_into_direction() -> void:
	var node: Node2D = _make_node()
	Juice.walk_tilt(node, Vector2(300.0, 0.0))
	await wait_seconds(Juice.TILT_TIME + 0.05)
	assert_almost_eq(node.rotation, deg_to_rad(Juice.WALK_TILT_DEG), 0.001)


func test_hit_flash_without_shader_is_safe() -> void:
	var node: Node2D = _make_node()
	assert_null(Juice.hit_flash(node))
