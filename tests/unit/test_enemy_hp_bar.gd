extends GutTest
## Phase 15, Paket 4: HP-Leisten unter normalen Gegnern (Option) und Tier-Kontur der schwebenden Waffen.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const WEAPON_SCENE: PackedScene = preload("res://scenes/weapons/weapon.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const GLASSCHERBE: WeaponData = preload("res://data/weapons/glasscherbe.tres")

var _player: Player
var _old_mode: EnemyHpBar.Mode


func before_each() -> void:
	GameState.start_run(45)
	_old_mode = EnemyHpBar.mode
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	EnemyHpBar.mode = _old_mode


func _enemy(elite: bool = false, boss: bool = false) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = 100.0
	data.is_elite = elite
	data.is_boss = boss
	enemy.setup(data)
	enemy.activate(1, Vector2(400, 0), _player, Rect2(), _player.rng)
	enemy.set_physics_process(false)
	return enemy


func _bar(enemy: Enemy) -> EnemyHpBar:
	return enemy.get("_hp_bar") as EnemyHpBar


func test_visibility_rules() -> void:
	assert_true(EnemyHpBar.should_show(EnemyHpBar.Mode.ALWAYS, 1.0))
	assert_true(EnemyHpBar.should_show(EnemyHpBar.Mode.ALWAYS, 0.4))
	assert_false(EnemyHpBar.should_show(EnemyHpBar.Mode.DAMAGED, 1.0))
	assert_true(EnemyHpBar.should_show(EnemyHpBar.Mode.DAMAGED, 0.4))
	assert_false(EnemyHpBar.should_show(EnemyHpBar.Mode.OFF, 0.4))
	assert_false(EnemyHpBar.should_show(EnemyHpBar.Mode.ALWAYS, 0.0), "tote Gegner ohne Leiste")


func test_default_is_only_when_damaged() -> void:
	assert_eq(EnemyHpBar.DEFAULT_MODE, EnemyHpBar.Mode.DAMAGED)
	assert_eq(EnemyHpBar.MODE_KEYS.size(), EnemyHpBar.Mode.size())


func test_only_normal_enemies_get_a_bar() -> void:
	assert_not_null(_bar(_enemy()))
	assert_null(_bar(_enemy(true)), "Elites behalten die große Leiste oben")
	assert_null(_bar(_enemy(false, true)), "Bosse behalten die große Leiste oben")


func test_bar_appears_after_damage_in_default_mode() -> void:
	EnemyHpBar.mode = EnemyHpBar.Mode.DAMAGED
	var enemy: Enemy = _enemy()
	assert_false(_bar(enemy).visible)
	enemy.take_damage(DamageInfo.create(10, false, 0.0, null))
	assert_true(_bar(enemy).visible)
	enemy.heal(1000.0)
	assert_false(_bar(enemy).visible, "voll geheilt")


func test_always_and_off_modes() -> void:
	EnemyHpBar.mode = EnemyHpBar.Mode.ALWAYS
	var enemy: Enemy = _enemy()
	assert_true(_bar(enemy).visible)
	EnemyHpBar.mode = EnemyHpBar.Mode.OFF
	get_tree().call_group(EnemyHpBar.GROUP, &"refresh_mode")
	assert_false(_bar(enemy).visible, "Umschalten wirkt sofort")
	enemy.take_damage(DamageInfo.create(10, false, 0.0, null))
	assert_false(_bar(enemy).visible)


func test_bar_hides_on_death_and_resets_on_reuse() -> void:
	EnemyHpBar.mode = EnemyHpBar.Mode.DAMAGED
	var enemy: Enemy = _enemy()
	enemy.take_damage(DamageInfo.create(500, false, 0.0, null))
	assert_false(_bar(enemy).visible)
	enemy.activate(1, Vector2(400, 0), _player, Rect2(), _player.rng)
	assert_false(_bar(enemy).visible, "aus dem Pool mit voller HP")


func test_weapon_outline_uses_tier_color() -> void:
	for tier: int in range(1, 5):
		var weapon: Weapon = WEAPON_SCENE.instantiate()
		weapon.setup(GLASSCHERBE, tier, _player)
		add_child_autofree(weapon)
		var material: ShaderMaterial = (weapon.get_node("Sprite") as Sprite2D).material as ShaderMaterial
		assert_not_null(material)
		var color: Color = material.get_shader_parameter(Weapon.OUTLINE_COLOR_PARAM)
		var expected: Color = UiStyle.tier_color(tier)
		assert_almost_eq(color.r, expected.r, 0.01)
		assert_almost_eq(color.b, expected.b, 0.01)
		assert_gt(color.a, 0.5, "deutlich sichtbar")
