extends GutTest
## Tests für Waffen-Besonderheiten: Set-Boni, Ketten-Blitz, Explosion, Zielsuche, Brand, Heilung, Strukturen.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/enemies/training_dummy.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/projectile.tscn")
const STRUCTURE_SCENE: PackedScene = preload("res://scenes/structures/structure.tscn")

var _player: Player


func before_each() -> void:
	GameState.start_run(8)
	_player = PLAYER_SCENE.instantiate()
	_player.rng = RandomNumberGenerator.new()
	add_child_autofree(_player)
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = PROJECTILE_SCENE
	pool.group_name = Pools.PLAYER_PROJECTILES
	add_child_autofree(pool)


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	add_child_autofree(dummy)
	dummy.global_position = at
	dummy.knockback_resistance = 1.0
	return dummy


func _spec(info: DamageInfo) -> ProjectileSpec:
	var spec: ProjectileSpec = ProjectileSpec.new()
	spec.texture = load("res://art/fx/projectile_spark.svg")
	spec.speed = 1200.0
	spec.max_range = 800.0
	spec.info = info
	spec.player = _player
	return spec


func _shoot(spec: ProjectileSpec, angle: float = 0.0) -> void:
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	add_child_autofree(projectile)
	projectile.launch(Vector2(0, -36), angle, spec)


func test_set_bonus_scales_with_weapon_count() -> void:
	var shard: WeaponData = load("res://data/weapons/glasscherbe.tres")
	var whip: WeaponData = load("res://data/weapons/kabelpeitsche.tres")
	_player.weapon_slots.add_weapon(shard)
	assert_eq(_player.stats.get_stat(Stats.CRIT_CHANCE), 0.0, "1 Präzise-Waffe: kein Bonus")
	_player.weapon_slots.add_weapon(whip)
	assert_eq(_player.stats.get_stat(Stats.CRIT_CHANCE), 3.0, "2 Präzise: +3 %")
	var third: Weapon = _player.weapon_slots.add_weapon(whip)
	assert_eq(_player.stats.get_stat(Stats.CRIT_CHANCE), 6.0, "3 Präzise: +6 %")
	assert_eq(_player.stats.get_stat(Stats.MELEE_DMG), 0.0, "Klinge erst ab 2")
	_player.weapon_slots.remove_weapon(third)
	assert_eq(_player.stats.get_stat(Stats.CRIT_CHANCE), 3.0)


func test_set_bonus_multiplier_doubles() -> void:
	_player.set_bonus_multiplier[WeaponClasses.PRIMITIVE] = 2.0
	var branch: WeaponData = load("res://data/weapons/ast.tres")
	_player.weapon_slots.add_weapon(branch)
	_player.weapon_slots.add_weapon(branch)
	assert_eq(_player.get_max_hp(), 10.0 + 6.0)


func test_chain_lightning_hits_more_targets() -> void:
	var a: TrainingDummy = _dummy(Vector2(150, 0))
	var b: TrainingDummy = _dummy(Vector2(250, 0))
	var c: TrainingDummy = _dummy(Vector2(350, 0))
	var spec: ProjectileSpec = _spec(DamageInfo.create(5, false, 0.0, null))
	spec.chain_count = 2
	spec.chain_range = 220.0
	_shoot(spec)
	await wait_seconds(0.4)
	assert_eq([a.total_damage, b.total_damage, c.total_damage], [5, 5, 5])


func test_explosion_projectile_hits_group() -> void:
	var a: TrainingDummy = _dummy(Vector2(200, 0))
	var b: TrainingDummy = _dummy(Vector2(230, 30))
	var spec: ProjectileSpec = _spec(DamageInfo.create(20, false, 0.0, null))
	spec.explosion_radius = 75.0
	_shoot(spec)
	await wait_seconds(0.4)
	assert_eq(a.total_damage, 20)
	assert_eq(b.total_damage, 20)


func test_homing_projectile_curves_to_target() -> void:
	var target: TrainingDummy = _dummy(Vector2(250, 220))
	var spec: ProjectileSpec = _spec(DamageInfo.create(7, false, 0.0, null))
	spec.speed = 500.0
	spec.homing_turn_deg = 360.0
	_shoot(spec, 0.0)
	await wait_seconds(1.5)
	assert_eq(target.total_damage, 7, "trotz Schuss nach rechts getroffen")


func test_heal_on_hit() -> void:
	_dummy(Vector2(150, 0))
	_player.take_hit(3.0)
	var info: DamageInfo = DamageInfo.create(1, false, 0.0, null)
	info.heal_on_hit_chance = 1.0
	_shoot(_spec(info))
	await wait_seconds(0.4)
	assert_eq(_player.current_hp, 8.0)


func test_burn_deals_damage_over_time() -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = (load("res://data/enemies/schattenling.tres") as EnemyData).duplicate()
	data.base_hp = 100.0
	enemy.setup(data)
	enemy.activate(1, Vector2(600, 0), _player, Rect2(), _player.rng)
	enemy.apply_burn(4.0, 3, _player)
	await wait_seconds(3.3)
	assert_almost_eq(enemy.hp, 100.0 - 12.0, 0.01)
	assert_false(enemy.is_burning())


func test_structure_shoots_with_engineering_damage() -> void:
	var dummy: TrainingDummy = _dummy(Vector2(200, 0))
	_player.stats.add_modifier(StatModifier.create(Stats.ENGINEERING, 5.0))
	_player.stats.add_modifier(StatModifier.create(Stats.DAMAGE_PCT, 100.0))
	var structure: Structure = STRUCTURE_SCENE.instantiate() as Structure
	structure.setup(load("res://data/structures/lampenturm.tres"), 1, _player)
	add_child_autofree(structure)
	await wait_seconds(0.6)
	assert_eq(structure.get_damage(), 10, "5 + 100 % Technik, Schaden-% zählt nicht")
	assert_gt(dummy.total_damage, 0)


func test_all_weapons_describe_without_missing_keys() -> void:
	for res: Resource in DataRegistry.get_all("weapons"):
		var text: String = TextFormat.describe_weapon(res as WeaponData, 1)
		assert_false(text.contains("WEAPON_"), "Übersetzung fehlt in: " + text)
