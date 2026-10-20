extends GutTest
## Integration: Spieler mit Waffen trifft einen Trainings-Dummy (Nahkampf und Fernkampf).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/enemies/training_dummy.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/projectile.tscn")

var _player: Player
var _dummy: TrainingDummy


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.rng = RandomNumberGenerator.new()
	_player.rng.seed = 7
	add_child_autofree(_player)
	_player.global_position = Vector2.ZERO
	_dummy = DUMMY_SCENE.instantiate()
	add_child_autofree(_dummy)
	_dummy.global_position = Vector2(110, 0)
	_dummy.knockback_resistance = 1.0


func test_slots_respect_maximum() -> void:
	var data: WeaponData = load("res://data/weapons/ast.tres")
	for i in _player.config.weapon_slots:
		assert_not_null(_player.weapon_slots.add_weapon(data))
	assert_null(_player.weapon_slots.add_weapon(data), "voll")
	assert_eq(_player.weapon_slots.count_of(&"ast"), _player.config.weapon_slots)


func test_weapons_are_spread_in_a_circle() -> void:
	var data: WeaponData = load("res://data/weapons/ast.tres")
	var a: Weapon = _player.weapon_slots.add_weapon(data)
	var b: Weapon = _player.weapon_slots.add_weapon(data)
	assert_almost_eq(a.rest_position.length(), _player.config.weapon_orbit_radius, 0.01)
	assert_almost_eq(absf(a.rest_position.angle_to(b.rest_position)), PI, 0.01, "gegenüberliegend")


func test_melee_weapon_hits_dummy() -> void:
	_player.weapon_slots.add_weapon(load("res://data/weapons/funkenfaust.tres"))
	await wait_seconds(1.0)
	assert_gt(_dummy.total_damage, 0, "Funkenfaust sollte den Dummy treffen")


func test_ranged_weapon_hits_dummy_with_pooled_projectiles() -> void:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = PROJECTILE_SCENE
	pool.group_name = Pools.PLAYER_PROJECTILES
	add_child_autofree(pool)
	pool.prewarm(4)
	_dummy.global_position = Vector2(300, 0)
	_player.weapon_slots.add_weapon(load("res://data/weapons/funkenpistole.tres"))
	await wait_seconds(1.0)
	assert_gt(_dummy.total_damage, 0, "Projektil sollte den Dummy treffen")


func test_ast_gets_bonus_per_other_ast() -> void:
	var data: WeaponData = load("res://data/weapons/ast.tres")
	var first: Weapon = _player.weapon_slots.add_weapon(data)
	_player.weapon_slots.add_weapon(data)
	_player.weapon_slots.add_weapon(data)
	_player.rng.seed = 1
	var info: DamageInfo = first._roll_damage()
	var base: int = 10 + 2
	assert_true(info.amount == base or info.amount == base * 2, "10 Basis + 2 weitere Äste, war %d" % info.amount)
