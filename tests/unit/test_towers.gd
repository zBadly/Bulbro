extends GutTest
## Phase 15, Paket 8: Türme. Turm-Items (jedes Exemplar ein Turm), Platzierung im Ring um den Spieler,
## Obergrenzen für Türme und Minen, Wirkung der vier Türme, Skalierung mit Technik und Struktur-Angriffstempo,
## Herkunft in der Run-Statistik und Freischaltungen, die nur Lampentürme zählen.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const STRUCTURE_SCENE: PackedScene = preload("res://scenes/structures/structure.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const SCHRAUBENZIEHER: WeaponData = preload("res://data/weapons/schraubenzieher.tres")
const TOWERS: TowerConfig = preload("res://data/config/tower_config.tres")
const TOWER_IDS: Array[String] = ["flammenturm", "frostturm", "heilturm", "stolperdraht"]
const AREA: Rect2 = Rect2(-1000, -1000, 2000, 2000)

var _player: Player
var _container: Node2D
var _builder: TowerBuilder


func before_each() -> void:
	GameState.start_run(41)
	GameState.phase = GameState.Phase.WAVE
	_container = Node2D.new()
	add_child_autofree(_container)
	_player = PLAYER_SCENE.instantiate()
	_player.rng = RandomNumberGenerator.new()
	_container.add_child(_player)
	_builder = TowerBuilder.new()
	_builder.player = _player
	_builder.container = _container
	_builder.ground = _container
	_builder.area = AREA
	add_child_autofree(_builder)


## Türme werden verzögert eingehängt (call_deferred): erst abbauen und Frames abwarten, sonst bleiben sie verwaist.
func after_each() -> void:
	_builder.clear()
	await wait_process_frames(2)


func after_all() -> void:
	await wait_process_frames(1)


func _item(id: String) -> ItemData:
	return load("res://data/items/%s.tres" % id)


func _structure(id: String) -> StructureData:
	return load("res://data/structures/%s.tres" % id)


func _give(id: String, count: int) -> void:
	for i in count:
		GameState.add_item(_item(id))
		_player.apply_item(_item(id))


func _enemy(at: Vector2, hp: float = 1000.0) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = hp
	enemy.setup(data)
	enemy.activate(1, at, _player, Rect2(), _player.rng)
	enemy.set_physics_process(false)
	return enemy


func _tower(id: String, at: Vector2) -> Structure:
	var structure: Structure = STRUCTURE_SCENE.instantiate() as Structure
	structure.setup(_structure(id), 1, _player)
	structure.position = at
	_container.add_child(structure)
	structure.set_physics_process(false)
	return structure


# --- Daten und Beschreibung ---

func test_tower_items_are_stackable_structure_items() -> void:
	for id: String in TOWER_IDS:
		var item: ItemData = _item(id)
		assert_eq(item.limit, 0, id + " stapelbar")
		assert_has(item.tags, &"structure", id)
		assert_true(item.effects[0] is TowerItemEffect, id)
		var text: String = item.get_description()
		assert_string_contains(text, tr("STRUCTURE_" + id.to_upper()))
		assert_false(text.contains("%s"), id + " ohne offene Platzhalter")


func test_tower_items_do_not_change_rebuild() -> void:
	_give("frostturm", 2)
	var triggers: int = _player.triggers.size()
	_player.rebuild()
	assert_eq(_player.triggers.size(), triggers, "Turm-Items sind keine Trigger")


# --- Bauen und Platzieren ---

func test_each_copy_builds_one_tower_after_weapon_towers() -> void:
	_player.weapon_slots.add_weapon(SCHRAUBENZIEHER)
	_give("frostturm", 2)
	_give("heilturm", 1)
	var requests: Array[Array] = _builder.wave_requests()
	var ids: Array[StringName] = []
	for request: Array in requests:
		ids.append((request[0] as StructureData).id)
	assert_eq(ids, [&"lampenturm", &"frostturm", &"frostturm", &"heilturm"] as Array[StringName])


func test_towers_land_in_ring_inside_arena_and_apart() -> void:
	_give("frostturm", 3)
	_give("flammenturm", 3)
	_builder.build_wave()
	await wait_process_frames(2)
	var towers: Array[Structure] = _builder.towers()
	assert_eq(towers.size(), 6)
	for i in towers.size():
		var dist: float = towers[i].position.distance_to(_player.global_position)
		assert_between(dist, TOWERS.ring_min_radius - 0.01, TOWERS.ring_max_radius + 0.01, "im Ring")
		for j in range(i + 1, towers.size()):
			assert_gte(towers[i].position.distance_to(towers[j].position), TOWERS.min_spacing, "nicht übereinander")


func test_towers_stay_inside_arena_at_the_edge() -> void:
	_player.global_position = AREA.end - Vector2(5, 5)
	_give("heilturm", 6)
	_builder.build_wave()
	var inner: Rect2 = AREA.grow(-TOWERS.edge_margin)
	for tower: Structure in _builder.towers():
		assert_true(inner.grow(0.01).has_point(tower.position), "innerhalb der Arena: %s" % tower.position)


func test_tower_cap_keeps_lamp_towers_first() -> void:
	_player.weapon_slots.add_weapon(SCHRAUBENZIEHER)
	_player.weapon_slots.add_weapon(SCHRAUBENZIEHER)
	_give("frostturm", TOWERS.max_towers + 5)
	_builder.build_wave()
	assert_eq(_builder.towers().size(), TOWERS.max_towers)
	assert_eq(_builder.lamp_tower_count(), 2, "Lampentürme der Waffen zuerst")


func test_mine_cap_removes_oldest() -> void:
	var data: StructureData = _structure("stolperdraht")
	var first: Mine = _builder.add_mine(data, Vector2.ZERO)
	for i in TOWERS.max_mines:
		_builder.add_mine(data, Vector2(i * 10, 0))
	assert_eq(_builder.mines().size(), TOWERS.max_mines)
	assert_true(first.is_queued_for_deletion(), "die älteste Mine verschwindet")


func test_exploded_mines_and_freed_towers_are_dropped() -> void:
	var data: StructureData = _structure("stolperdraht")
	var mine: Mine = _builder.add_mine(data, Vector2(500, 500))
	_builder.add_mine(data, Vector2(-500, 500))
	var tower: Structure = _builder.build(data, 1, Vector2(300, 0))
	await wait_process_frames(1)
	mine.detonate()
	tower.queue_free()
	await wait_process_frames(2)
	assert_eq(_builder.mines().size(), 1, "explodierte Mine ist weg")
	assert_eq(_builder.towers().size(), 0, "freigegebener Turm ist weg")


func test_clear_removes_towers_and_mines() -> void:
	_give("stolperdraht", 2)
	_builder.build_wave()
	_builder.add_mine(_structure("stolperdraht"), Vector2.ZERO)
	_builder.clear()
	assert_eq(_builder.towers().size(), 0)
	assert_eq(_builder.mines().size(), 0)


func test_resume_rebuilds_tower_items() -> void:
	GameState.character = load("res://data/characters/taschenlampe.tres")
	_player.apply_character(GameState.character)
	_give("frostturm", 2)
	_give("stolperdraht", 1)
	var data: Dictionary = RunSave.capture(_player)
	RunSave.restore_state(data)
	var copy: Player = PLAYER_SCENE.instantiate()
	copy.rng = RandomNumberGenerator.new()
	_container.add_child(copy)
	RunSave.apply_to_player(data, copy)
	_builder.player = copy
	assert_eq(GameState.items.size(), 3, "Turm-Items im Fortsetzen-Stand")
	_builder.build_wave()
	assert_eq(_builder.towers().size(), 3, "nach dem Fortsetzen wieder gebaut")


# --- Freischaltungen: nur Lampentürme ---

func test_five_frost_towers_do_not_unlock_drohnenleuchte() -> void:
	_give("frostturm", 5)
	_builder.build_wave()
	assert_eq(_builder.towers().size(), 5)
	assert_eq(GameState.run_stats.current_turrets, 0)
	assert_eq(GameState.max_structures, 0)
	var drohne: ChallengeData = Unlocks.challenge_for(load("res://data/characters/drohnenleuchte.tres"))
	var lampe: ChallengeData = Unlocks.challenge_for(load("res://data/characters/taschenlampe.tres"))
	assert_false(drohne.is_met(Unlocks.make_context(true, true)), "5 Frosttürme zählen nicht")
	assert_false(lampe.is_met(Unlocks.make_context(false, false)))


func test_five_lamp_towers_unlock_drohnenleuchte() -> void:
	for i in 5:
		_player.weapon_slots.add_weapon(SCHRAUBENZIEHER)
	_give("frostturm", 3)
	_builder.build_wave()
	assert_eq(GameState.run_stats.current_turrets, 5)
	assert_eq(GameState.max_structures, 5)
	var drohne: ChallengeData = Unlocks.challenge_for(load("res://data/characters/drohnenleuchte.tres"))
	var lampe: ChallengeData = Unlocks.challenge_for(load("res://data/characters/taschenlampe.tres"))
	assert_true(drohne.is_met(Unlocks.make_context(true, false)), "5 Lampentürme am Run-Ende")
	assert_true(lampe.is_met(Unlocks.make_context(false, false)))


# --- Wirkung ---

func test_frost_tower_slows_enemies_in_aura() -> void:
	var tower: Structure = _tower("frostturm", Vector2.ZERO)
	await wait_process_frames(1)
	var near: Enemy = _enemy(Vector2(100, 0))
	var far: Enemy = _enemy(Vector2(400, 0))
	tower.call("_chill_enemies")
	assert_almost_eq(near.slow.speed_factor(), 0.7, 0.001, "30 % langsamer")
	assert_eq(far.slow.speed_factor(), 1.0)


func test_heal_tower_heals_only_inside_radius() -> void:
	var tower: Structure = _tower("heilturm", Vector2.ZERO)
	await wait_process_frames(1)
	_player.current_hp = 5.0
	_player.global_position = Vector2(50, 0)
	tower.call("_heal_player")
	assert_eq(_player.current_hp, 6.0, "1 HP")
	_player.global_position = Vector2(500, 0)
	tower.call("_heal_player")
	assert_eq(_player.current_hp, 6.0, "außerhalb des Radius")


func test_flame_tower_hits_beam_and_burns() -> void:
	var tower: Structure = _tower("flammenturm", Vector2.ZERO)
	await wait_process_frames(1)
	var muzzle: Vector2 = (tower.get_node("Muzzle") as Node2D).global_position
	var target: Enemy = _enemy(Vector2.ZERO)
	var hit_offset: Vector2 = target.get_hit_position() - target.global_position
	target.global_position = muzzle + Vector2(150, 0) - hit_offset
	var behind: Enemy = _enemy(muzzle + Vector2(70, 0) - hit_offset)
	var aside: Enemy = _enemy(muzzle + Vector2(100, 200))
	var hp: float = aside.hp
	tower.call("_flame", target)
	var origin: StringName = DamageSource.structure(&"flammenturm")
	assert_true(target.is_burning(), "Brand")
	assert_true(behind.is_burning(), "trifft alles auf dem Strahl")
	assert_eq(aside.hp, hp, "neben dem Strahl kein Treffer")
	assert_gt(GameState.run_stats.damage_of(origin), 0, "Schaden zählt für den Flammenturm")


func test_flame_beam_hits_at_most_max_targets_nearest_first() -> void:
	var tower: Structure = _tower("flammenturm", Vector2.ZERO)
	await wait_process_frames(1)
	var data: StructureData = _structure("flammenturm")
	var muzzle: Vector2 = (tower.get_node("Muzzle") as Node2D).global_position
	var probe: Enemy = _enemy(Vector2.ZERO)
	var hit_offset: Vector2 = probe.get_hit_position() - probe.global_position
	probe.global_position = muzzle + Vector2(0, 600)
	var line: Array[Enemy] = []
	for i in data.beam_max_targets + 2:
		line.append(_enemy(muzzle + Vector2(30 + i * 25, 0) - hit_offset))
	tower.call("_flame", line[0])
	for i in line.size():
		assert_eq(line[i].is_burning(), i < data.beam_max_targets, "Treffer %d" % i)


## Tooltip und Lexikon nutzen describe(): Die Trefferzahl kommt aus beam_max_targets.
func test_flame_description_names_max_targets() -> void:
	var data: StructureData = _structure("flammenturm")
	var text: String = " ".join(data.describe())
	assert_string_contains(text, "trifft bis zu %d Gegner" % data.beam_max_targets)


func test_mine_explodes_as_structure_damage_without_damage_pct() -> void:
	var data: StructureData = _structure("stolperdraht")
	_player.add_run_modifier(StatModifier.create(Stats.DAMAGE_PCT, 100.0))
	var enemy: Enemy = _enemy(Vector2(0, 20))
	var hp: float = enemy.hp
	var mine: Mine = _builder.add_mine(data, enemy.get_hit_position())
	mine.detonate()
	assert_eq(roundi(hp - enemy.hp), data.mine_damage(_player.stats), "ohne Schaden-%")
	assert_eq(GameState.run_stats.damage_of(DamageSource.structure(&"stolperdraht")), data.mine_damage(_player.stats))


func test_mine_layer_requests_mines_near_tower() -> void:
	var tower: Structure = _builder.build(_structure("stolperdraht"), 1, Vector2(200, 0))
	await wait_process_frames(1)
	tower.call("_lay_mine")
	var mines: Array[Mine] = _builder.mines()
	assert_eq(mines.size(), 1)
	assert_lte(mines[0].position.distance_to(tower.position), _structure("stolperdraht").mine_spread + 0.01)


# --- Skalierung ---

func test_engineering_and_structure_speed_scale_towers() -> void:
	var flame: StructureData = _structure("flammenturm")
	var frost: StructureData = _structure("frostturm")
	var heal: StructureData = _structure("heilturm")
	var mines: StructureData = _structure("stolperdraht")
	var damage: int = flame.damage(_player.stats)
	var radius: float = frost.aura(_player.stats)
	var cooldown: float = mines.cooldown(1, _player.stats)
	var mine_damage: int = mines.mine_damage(_player.stats)
	_player.add_run_modifier(StatModifier.create(Stats.ENGINEERING, 20.0))
	_player.add_run_modifier(StatModifier.create(Stats.STRUCTURE_ATTACK_SPEED_PCT, 100.0))
	assert_gt(flame.damage(_player.stats), damage)
	assert_gt(flame.burn_tick(_player.stats), flame.burn_damage)
	assert_gt(frost.aura(_player.stats), radius)
	assert_eq(heal.heal(_player.stats), 2, "1 HP + 5 % von 20 Technik")
	assert_eq(mines.mine_damage(_player.stats), mine_damage + 20)
	assert_almost_eq(mines.cooldown(1, _player.stats), cooldown * 0.5, 0.001)


func test_tool_set_engineering_reaches_towers() -> void:
	var flame: StructureData = _structure("flammenturm")
	var before: int = flame.damage(_player.stats)
	for i in 6:
		_player.weapon_slots.add_weapon(SCHRAUBENZIEHER)
	assert_gt(_player.stats.get_stat(Stats.ENGINEERING), 0.0, "Werkzeug-Set gibt Technik")
	assert_gt(flame.damage(_player.stats), before)
