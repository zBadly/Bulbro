extends GutTest
## Phase 15, Paket 4: Kills und Schaden je Herkunft (Waffe, Item, Charakter, Brand, Fluch), Grundlage für Paket 5.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const WEAPON_SCENE: PackedScene = preload("res://scenes/weapons/weapon.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const GLASSCHERBE: WeaponData = preload("res://data/weapons/glasscherbe.tres")
const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")

var _player: Player
var _system: EffectSystem


func before_each() -> void:
	GameState.start_run(43)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_system = EffectSystem.new()
	add_child_autofree(_system)
	_system.player = _player


func _enemy(hp: float, at: Vector2) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = hp
	enemy.setup(data)
	enemy.activate(1, at, _player, Rect2(), _player.rng)
	enemy.set_physics_process(false)
	return enemy


func _weapon() -> Weapon:
	var weapon: Weapon = WEAPON_SCENE.instantiate()
	weapon.setup(GLASSCHERBE, 1, _player)
	add_child_autofree(weapon)
	return weapon


func test_origin_keys() -> void:
	var origin: StringName = DamageSource.weapon(&"ast")
	assert_eq(origin, &"weapon/ast")
	assert_eq(DamageSource.kind_of(origin), DamageSource.WEAPON)
	assert_eq(DamageSource.id_of(origin), &"ast")
	assert_eq(DamageSource.kind_of(DamageSource.ally()), DamageSource.ALLY)
	assert_eq(DamageSource.id_of(DamageSource.ally()), &"")


func test_weapon_hit_records_damage_and_kill_without_overkill() -> void:
	var info: DamageInfo = _weapon().call("_roll_damage")
	var origin: StringName = DamageSource.weapon(GLASSCHERBE.id)
	assert_eq(info.origin, origin)
	var tough: Enemy = _enemy(1000.0, Vector2(400, 0))
	tough.take_damage(info)
	assert_eq(GameState.run_stats.damage_of(origin), info.amount)
	var weak: Enemy = _enemy(1.0, Vector2(500, 0))
	var hp_before: int = ceili(weak.hp)
	var big: DamageInfo = DamageInfo.create(500, false, 0.0, null, origin)
	weak.take_damage(big)
	assert_false(weak.is_alive())
	assert_eq(GameState.run_stats.damage_of(origin), info.amount + hp_before, "nur die echten Rest-HP zählen")
	assert_eq(GameState.run_stats.kills_of(origin), 1)
	assert_eq(GameState.run_stats.enemies_killed, 1)


func test_hits_without_origin_are_not_attributed() -> void:
	var enemy: Enemy = _enemy(1.0, Vector2(400, 0))
	enemy.take_damage(DamageInfo.create(5, false, 0.0, null))
	assert_true(GameState.run_stats.source_kills.is_empty())
	assert_true(GameState.run_stats.source_damage.is_empty())
	assert_eq(GameState.run_stats.enemies_killed, 1)


func test_burn_and_spread_keep_their_origin() -> void:
	var origin: StringName = DamageSource.weapon(&"loetkolben")
	var enemy: Enemy = _enemy(1000.0, Vector2(400, 0))
	enemy.apply_burn(5.0, 2, _player, origin)
	enemy.call("_update_burn", COMBAT.burn_interval)
	assert_eq(GameState.run_stats.damage_of(origin), 5)


func test_curse_ticks_keep_their_origin() -> void:
	var origin: StringName = DamageSource.weapon(&"voodoo_nadel")
	var enemy: Enemy = _enemy(1000.0, Vector2(400, 0))
	enemy.apply_curse(4.0, 0.0, 5.0, 1, origin)
	enemy.call("_update_statuses", 1.0)
	assert_gt(GameState.run_stats.damage_of(origin), 0)


func test_item_trigger_damage_is_attributed_to_the_item() -> void:
	var item: ItemData = ItemData.new()
	item.id = &"test_overheal"
	var effect: OverhealDamageEffect = OverhealDamageEffect.new()
	item.effects = [effect]
	GameState.add_item(item)
	_player.apply_item(item)
	var enemy: Enemy = _enemy(1000.0, Vector2(300, 0))
	assert_eq(_player.triggers[0].origin, DamageSource.item(item.id))
	_player.take_hit(1.0)
	_player.heal(3.0)
	assert_eq(GameState.run_stats.damage_of(DamageSource.item(item.id)), 2, "1 HP geheilt, 2 HP Überschuss als Schaden")
	assert_true(enemy.is_alive())


func test_character_triggers_get_character_origin() -> void:
	var character: CharacterData = CharacterData.new()
	character.id = &"test_char"
	var effect: OverhealDamageEffect = OverhealDamageEffect.new()
	character.effects = [effect]
	_player.call("_apply_character_rules", character)
	assert_eq(_player.triggers.size(), 1)
	assert_eq(_player.triggers[0].origin, DamageSource.character(&"test_char"))


func test_explosion_action_keeps_origin_after_delay() -> void:
	var item: ItemData = ItemData.new()
	item.id = &"test_bomb"
	var action: ExplosionAction = ExplosionAction.new()
	action.radius = 100.0
	action.base_damage = 6.0
	var ctx: EffectContext = EffectContext.create(_player)
	ctx.origin = DamageSource.item(item.id)
	var enemy: Enemy = _enemy(1000.0, Vector2(400, 0))
	action.execute(ctx, enemy.get_hit_position())
	ctx.origin = &"anders"
	assert_eq(GameState.run_stats.damage_of(DamageSource.item(item.id)), 6)


func test_source_stats_survive_save_and_resume() -> void:
	var stats: RunStats = RunStats.new()
	stats.record_damage(&"weapon/ast", 120)
	stats.record_damage(&"weapon/ast", 30)
	stats.record_kill(&"item/supernova")
	stats.record_damage(&"", 50)
	var restored: RunStats = RunStats.from_dict(JSON.parse_string(JSON.stringify(stats.to_dict())))
	assert_eq(restored.damage_of(&"weapon/ast"), 150)
	assert_eq(restored.kills_of(&"item/supernova"), 1)
	assert_eq(restored.source_damage.size(), 1, "Treffer ohne Herkunft werden nicht gespeichert")
