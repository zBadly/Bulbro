extends GutTest
## Paket 2: die 5 neuen Startwaffen (Daten, Tier-Faustregel, Sondereffekte über die Systeme aus Paket 1).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/enemies/training_dummy.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/projectile.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const NEW_WEAPONS: Array[String] = ["seelenlaterne", "feuerzeugwerfer", "kristallstab", "voodoo_nadel", "dornenranke"]
const TIER_DAMAGE: Array[float] = [1.0, 1.5, 2.2, 3.2]
const TIER_COOLDOWN: Array[float] = [1.0, 0.92, 0.85, 0.78]
const TIER_PRICE: Array[float] = [1.0, 2.0, 3.6, 6.5]
const BURN_SAMPLES: int = 400

var _player: Player
var _pool: ObjectPool


func before_each() -> void:
	GameState.start_run(52)
	_player = PLAYER_SCENE.instantiate()
	_player.rng = RandomNumberGenerator.new()
	_player.rng.seed = 52
	add_child_autofree(_player)
	_pool = ObjectPool.new()
	_pool.scene = PROJECTILE_SCENE
	_pool.group_name = Pools.PLAYER_PROJECTILES
	add_child_autofree(_pool)


func _weapon(id: String) -> WeaponData:
	return load("res://data/weapons/%s.tres" % id)


func _enemy(hp: float, at: Vector2) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = hp
	enemy.setup(data)
	enemy.activate(1, at, _player, Rect2(), _player.rng)
	enemy.set_physics_process(false)
	return enemy


func _roll(id: String, tier: int = 1) -> DamageInfo:
	var weapon: Weapon = _player.weapon_slots.add_weapon(_weapon(id), tier)
	return weapon.call("_roll_damage")


func test_new_weapons_load_with_complete_tiers() -> void:
	for id: String in NEW_WEAPONS:
		var weapon: WeaponData = _weapon(id)
		assert_not_null(weapon, id)
		assert_eq(weapon.tiers.size(), WeaponData.MAX_TIER, id)
		assert_ne(tr(weapon.name_key), weapon.name_key, "Name übersetzt: " + id)
		assert_not_null(weapon.texture, id)
		var first: WeaponTierStats = weapon.tiers[0]
		for i in weapon.tiers.size():
			var t: WeaponTierStats = weapon.tiers[i]
			assert_eq(t.base_damage, roundf(first.base_damage * TIER_DAMAGE[i]), "%s Tier %d Schaden" % [id, i + 1])
			assert_almost_eq(t.cooldown, snappedf(first.cooldown * TIER_COOLDOWN[i], 0.01), 0.001, "%s Tier %d Abklingzeit" % [id, i + 1])
			assert_eq(t.price, roundi(first.price * TIER_PRICE[i]), "%s Tier %d Preis" % [id, i + 1])
		var text: String = TextFormat.describe_weapon(weapon, 1)
		assert_false(text.contains("WEAPON_"), "Beschreibung vollständig: " + text)


func test_start_values_match_plan() -> void:
	var lantern: WeaponTierStats = _weapon("seelenlaterne").tiers[0]
	assert_eq([lantern.base_damage, lantern.cooldown, lantern.range, lantern.price], [11.0, 1.1, 350.0, 30])
	assert_gt(lantern.homing_turn_deg, 0.0, "zielsuchend")
	var lighter: WeaponTierStats = _weapon("feuerzeugwerfer").tiers[0]
	assert_eq([lighter.base_damage, lighter.cooldown, lighter.range, lighter.price], [2.0, 0.25, 200.0, 35])
	assert_gte(lighter.piercing, TextFormat.PIERCE_ALL, "unbegrenzter Durchschlag")
	assert_almost_eq(lighter.burn_chance, 0.2, 0.001)
	var staff: WeaponTierStats = _weapon("kristallstab").tiers[0]
	assert_eq([staff.base_damage, staff.cooldown, staff.range, staff.price, staff.split_count], [10.0, 1.0, 400.0, 30, 3])
	var needle: WeaponTierStats = _weapon("voodoo_nadel").tiers[0]
	assert_eq([needle.base_damage, needle.cooldown, needle.range, needle.price, needle.piercing], [5.0, 0.65, 380.0, 25, 2])
	var vine: WeaponData = _weapon("dornenranke")
	assert_eq(vine.kind, WeaponData.Kind.SWING)
	assert_eq(vine.tiers[0].scalings, {Stats.MELEE_DMG: 1.0, Stats.ELEMENTAL_DMG: 0.5})
	assert_eq(vine.classes, [WeaponClasses.PRIMITIVE, WeaponClasses.MEDICAL])


func test_new_weapons_are_in_the_shop_pool() -> void:
	var shop: Shop = Shop.create_from_registry()
	var ids: Array[StringName] = []
	for weapon: WeaponData in shop.weapons:
		ids.append(weapon.id)
	for id: String in NEW_WEAPONS:
		assert_has(ids, StringName(id))


func test_soul_lantern_kills_give_extra_soul() -> void:
	var system: EffectSystem = EffectSystem.new()
	add_child_autofree(system)
	system.player = _player
	var reanimate: ReanimateEffect = ReanimateEffect.new()
	reanimate.max_souls = 100
	reanimate.souls_per_kill = 1
	reanimate.apply(_player)
	var info: DamageInfo = _roll("seelenlaterne")
	assert_eq(info.extra_souls, 1)
	var enemy: Enemy = _enemy(1.0, Vector2(300, 0))
	enemy.take_damage(info)
	assert_eq(GameState.souls.souls, 2, "1 Seele pro Kill + 1 von der Seelenlaterne")


func test_lighter_burns_about_twenty_percent_of_hits() -> void:
	var info: DamageInfo = _roll("feuerzeugwerfer")
	info.amount = 0
	var enemy: Enemy = _enemy(1_000_000.0, Vector2(300, 0))
	var burned: int = 0
	for i in BURN_SAMPLES:
		enemy.set("_burn_ticks_left", 0)
		Hits.apply_weapon_hit(enemy, info, _player, false)
		if enemy.is_burning():
			burned += 1
	var share: float = float(burned) / BURN_SAMPLES
	assert_between(share, 0.13, 0.27, "Brandchance pro Treffer ~20 %% (gemessen %.2f)" % share)


func test_crystal_staff_splits_into_three_shards() -> void:
	var target: TrainingDummy = DUMMY_SCENE.instantiate()
	target.position = Vector2(150, 0)
	add_child_autofree(target)
	var behind: TrainingDummy = DUMMY_SCENE.instantiate()
	behind.position = Vector2(260, 0)
	add_child_autofree(behind)
	var weapon_data: WeaponData = _weapon("kristallstab")
	var t: WeaponTierStats = weapon_data.tiers[0]
	var spec: ProjectileSpec = ProjectileSpec.new()
	spec.texture = weapon_data.projectile_texture
	spec.speed = 1200.0
	spec.max_range = 800.0
	spec.info = DamageInfo.create(20, false, 0.0, null)
	spec.player = _player
	spec.split_count = t.split_count
	spec.split_damage_pct = t.split_damage_pct
	spec.split_texture = weapon_data.split_projectile_texture
	var projectile: Projectile = _pool.acquire() as Projectile
	projectile.launch(Vector2(0, -target.hit_height), 0.0, spec)
	await wait_physics_frames(12)
	assert_eq(target.total_damage, 20, "Hauptgeschoss trifft einmal, Splitter treffen es nicht erneut")
	assert_eq(behind.total_damage, 6, "mittlerer Splitter: 30 % von 20")
	assert_eq(_pool.active_count(), 3 - 1, "3 Splitter, einer hat getroffen")


func test_thorn_vine_roots_enemies() -> void:
	var info: DamageInfo = _roll("dornenranke")
	assert_almost_eq(info.root_chance, 0.25, 0.001)
	assert_almost_eq(info.root_duration, 0.5, 0.001)
	info.root_chance = 1.0
	var enemy: Enemy = _enemy(1000.0, Vector2(100, 0))
	Hits.apply_weapon_hit(enemy, info, _player, false)
	assert_true(enemy.is_stopped(), "festgehalten")
	assert_almost_eq(enemy.slow.time_left, 0.5, 0.001)
