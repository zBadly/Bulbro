extends GutTest
## Tests für Charaktere (GDD 10), Sonderregeln, Freischaltbedingungen und Spannung.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const MELEE_ID: String = "res://data/weapons/glasscherbe.tres"


func before_each() -> void:
	GameState.character = null
	GameState.difficulty = null
	GameState.start_run(21)


func _char(id: String) -> CharacterData:
	return load("res://data/characters/%s.tres" % id)


func _player(id: String) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.rng = RandomNumberGenerator.new()
	add_child_autofree(player)
	player.apply_character(_char(id))
	return player


func test_all_twelve_characters_are_valid() -> void:
	var characters: Array[CharacterData] = Unlocks.all_characters()
	assert_eq(characters.size(), 12)
	for c: CharacterData in characters:
		assert_not_null(c.texture, String(c.id))
		assert_ne(tr(c.name_key), c.name_key, "Name: " + c.name_key)
		assert_false(c.starting_weapons.is_empty(), String(c.id))
		for weapon: WeaponData in c.starting_weapons:
			assert_true(c.can_use_weapon(weapon), "%s darf Startwaffe %s nicht tragen" % [c.id, weapon.id])
		var text: String = TextFormat.describe_character(c)
		assert_false(text.contains("EFFECT_") or text.contains("CHAR_RULE") or text.contains("STAT_"), text)
		assert_ne(Unlocks.condition_text(c), "", String(c.id))


func test_five_start_characters() -> void:
	var start: int = 0
	for c: CharacterData in Unlocks.all_characters():
		if c.unlock == CharacterData.Unlock.START:
			start += 1
	assert_eq(start, 5)


func test_standard_bulb_stats() -> void:
	var p: Player = _player("standardbirne")
	assert_eq(p.get_max_hp(), 15.0)
	assert_eq(p.stats.get_stat(Stats.HARVESTING), 8.0)


func test_boxer_attacks_faster_with_unarmed_only() -> void:
	var p: Player = _player("gluehfaden_boxer")
	var fist: Weapon = p.weapon_slots.add_weapon(load("res://data/weapons/funkenfaust.tres"))
	var shard: Weapon = p.weapon_slots.add_weapon(load(MELEE_ID))
	assert_almost_eq(fist.get_cooldown(), 0.78 / 1.5, 0.001)
	assert_almost_eq(shard.get_cooldown(), 0.8, 0.001)


func test_neon_tube_range_bonus_for_precise() -> void:
	var p: Player = _player("neonroehre")
	var shard: Weapon = p.weapon_slots.add_weapon(load(MELEE_ID))
	assert_eq(shard.get_range(), 150.0 + 100.0 * CombatMath.MELEE_RANGE_FACTOR)


func test_led_cannot_use_melee() -> void:
	var p: Player = _player("led_schuetze")
	assert_false(p.weapon_slots.can_accept(load(MELEE_ID), 1))
	var shop: Shop = Shop.create_from_registry()
	var ctx: ShopContext = ShopContext.new()
	ctx.rng = RandomNumberGenerator.new()
	ctx.weapon_allowed = p.can_use_weapon
	for i in 200:
		assert_false(shop.pick_weapon(ctx).is_melee())


func test_lava_lamp_blocks_melee_gains() -> void:
	var p: Player = _player("lavalampe")
	p.stats.add_modifier(StatModifier.create(Stats.MELEE_DMG, 6.0))
	p.stats.add_modifier(StatModifier.create(Stats.ELEMENTAL_DMG, 3.0))
	assert_eq(p.stats.get_stat(Stats.MELEE_DMG), 0.0)
	assert_almost_eq(p.stats.get_stat(Stats.ELEMENTAL_DMG), 5.0 + 3.0 * 1.33, 0.01, "Startbonus zählt nicht als Zuwachs")


func test_string_lights_twelve_slots_and_damage_per_weapon() -> void:
	var p: Player = _player("lichterkette")
	assert_eq(p.weapon_slots.max_slots, 12)
	for i in 3:
		p.weapon_slots.add_weapon(load("res://data/weapons/funkenpistole.tres"))
	assert_eq(p.stats.get_stat(Stats.DAMAGE_PCT), -15.0)


func test_camera_flash_converts_speed_and_standing_still() -> void:
	var p: Player = _player("blitzlicht")
	assert_eq(p.stats.get_stat(Stats.MELEE_DMG), 15.0, "30 % Tempo -> 15 Nah")
	await wait_physics_frames(2)
	assert_eq(p.stats.get_stat(Stats.ARMOR), -103.0, "steht still")
	p.velocity = Vector2.RIGHT
	p.call("_update_standing_still")
	assert_eq(p.stats.get_stat(Stats.ARMOR), -3.0)


func test_candle_doubles_primitive_and_bans_elemental() -> void:
	var p: Player = _player("kerze")
	var branch: WeaponData = load("res://data/weapons/ast.tres")
	p.weapon_slots.add_weapon(branch)
	p.weapon_slots.add_weapon(branch)
	assert_eq(p.get_max_hp(), 10.0 + 8.0 + 6.0)
	assert_false(p.weapon_slots.can_accept(load("res://data/weapons/blitzwerfer.tres"), 1))


func test_unlock_conditions() -> void:
	var run: RunStats = RunStats.new()
	assert_false(Unlocks.is_met(_char("taschenlampe"), run, 2, 0, false))
	assert_true(Unlocks.is_met(_char("taschenlampe"), run, 3, 0, false))
	assert_true(Unlocks.is_met(_char("discokugel"), run, 0, 300, false))
	run.healed = 200.0
	assert_true(Unlocks.is_met(_char("nachtlicht"), run, 0, 0, false))
	run.primitive_only = true
	assert_false(Unlocks.is_met(_char("kerze"), run, 0, 0, false), "nur bei Sieg")
	assert_true(Unlocks.is_met(_char("kerze"), run, 0, 0, true))
	run.primitive_only = false
	assert_false(Unlocks.is_met(_char("kerze"), run, 0, 0, true))


func test_difficulty_raises_enemy_hp() -> void:
	GameState.difficulty = load("res://data/difficulties/spannung_5.tres")
	var p: Player = _player("standardbirne")
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	enemy.setup(load("res://data/enemies/schattenling.tres"))
	enemy.activate(1, Vector2(500, 0), p, Rect2(), p.rng)
	assert_almost_eq(enemy.max_hp, 3.0 * 1.4, 0.001)
	assert_almost_eq(enemy.damage, 1.0 * 1.4, 0.001)
	GameState.difficulty = null


func test_default_setup_without_menu() -> void:
	assert_eq(GameState.character.id, &"standardbirne")
	assert_not_null(GameState.starting_weapon)
	assert_eq(GameState.difficulty.level, 0)
