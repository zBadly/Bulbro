extends GutTest
## Fluch (Schwarzlicht): Stapel, Dauer, Schaden über Zeit, Schadensbonus, Zähler gleichzeitig verfluchter Gegner.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")

var _player: Player


func before_each() -> void:
	GameState.start_run(21)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func _enemy(hp: float, at: Vector2) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = hp
	enemy.setup(data)
	enemy.activate(1, at, _player, Rect2(), _player.rng)
	enemy.set_physics_process(false)
	return enemy


func test_stacks_are_capped_and_duration_refreshes() -> void:
	var curse: CurseStatus = CurseStatus.new()
	curse.apply(3.0, 15.0, 4.0, 3, 1.0)
	curse.tick(2.5)
	curse.apply(3.0, 15.0, 4.0, 3, 1.0)
	assert_eq(curse.stacks, 2)
	assert_almost_eq(curse.time_left, 4.0, 0.001, "neuer Fluch setzt die Dauer zurück")
	curse.apply(3.0, 15.0, 4.0, 3, 1.0)
	curse.apply(3.0, 15.0, 4.0, 3, 1.0)
	assert_eq(curse.stacks, 3, "höchstens 3 Stapel")


func test_damage_taken_factor_per_stack() -> void:
	var curse: CurseStatus = CurseStatus.new()
	assert_eq(curse.damage_taken_factor(), 1.0)
	var expected: Array[float] = [1.15, 1.30, 1.45]
	for factor: float in expected:
		curse.apply(3.0, 15.0, 4.0, 3, 1.0)
		assert_almost_eq(curse.damage_taken_factor(), factor, 0.0001)


func test_damage_over_time_scales_with_stacks() -> void:
	var curse: CurseStatus = CurseStatus.new()
	curse.apply(3.0, 15.0, 4.0, 3, 1.0)
	assert_eq(curse.tick(0.5), 0, "vor dem ersten Tick")
	assert_eq(curse.tick(0.5), 3)
	curse.apply(3.0, 15.0, 4.0, 3, 1.0)
	assert_eq(curse.tick(1.0), 6, "zwei Stapel = 6 Schaden pro Sekunde")


func test_curse_expires() -> void:
	var curse: CurseStatus = CurseStatus.new()
	curse.apply(3.0, 15.0, 4.0, 3, 1.0)
	var total: int = 0
	for i in 5:
		total += curse.tick(1.0)
	assert_false(curse.is_active())
	assert_eq(total, 12, "4 Ticks à 3 Schaden, danach nichts mehr")
	assert_eq(curse.damage_taken_factor(), 1.0)


func test_cursed_enemy_takes_more_damage() -> void:
	var enemy: Enemy = _enemy(100.0, Vector2(400, 0))
	enemy.apply_curse(3.0, 15.0, 4.0, 3)
	enemy.take_damage(DamageInfo.create(20, false, 0.0, null))
	assert_almost_eq(enemy.hp, 100.0 - 23.0, 0.01, "20 x 1,15")
	enemy.call("_update_statuses", 1.0)
	assert_almost_eq(enemy.hp, 100.0 - 23.0 - 3.0, 0.01, "Fluch-Tick 3, ebenfalls verstärkt: roundi(3 x 1,15) = 3")


func test_curse_effect_applies_on_weapon_hit() -> void:
	var system: EffectSystem = EffectSystem.new()
	add_child_autofree(system)
	system.player = _player
	var effect: CurseOnHitEffect = CurseOnHitEffect.new()
	effect.duration = 4.0
	effect.damage_per_second = 3.0
	effect.damage_taken_pct = 15.0
	effect.max_stacks = 3
	effect.apply(_player)
	var enemy: Enemy = _enemy(1000.0, Vector2(400, 0))
	for i in 4:
		Hits.apply_weapon_hit(enemy, DamageInfo.create(1, false, 0.0, null), _player, false)
	assert_eq(enemy.curse.stacks, 3)


func test_simultaneously_cursed_enemies_are_counted() -> void:
	var a: Enemy = _enemy(100.0, Vector2(400, 0))
	var b: Enemy = _enemy(100.0, Vector2(500, 0))
	a.apply_curse(3.0, 15.0, 4.0, 3)
	a.apply_curse(3.0, 15.0, 4.0, 3)
	b.apply_curse(3.0, 15.0, 4.0, 3)
	assert_eq(get_tree().get_node_count_in_group(Enemy.CURSED_GROUP), 2)
	assert_eq(GameState.run_stats.max_cursed, 2)
	a.call("_update_statuses", 5.0)
	assert_eq(get_tree().get_node_count_in_group(Enemy.CURSED_GROUP), 1, "abgelaufener Fluch verlässt die Gruppe")
	b.despawn()
	assert_eq(get_tree().get_node_count_in_group(Enemy.CURSED_GROUP), 0)
	assert_eq(GameState.run_stats.max_cursed, 2, "Höchstwert bleibt")
