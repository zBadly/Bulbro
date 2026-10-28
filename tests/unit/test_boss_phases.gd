extends GutTest
## Phase 15, Paket 7: sichtbare Boss-/Elite-Phasen (Namen, Signal, Unverwundbarkeit mit "Immun", HP-Leiste, Lexikon).

const PHASES: BossPhaseConfig = preload("res://data/config/boss_phase_config.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const MARKER_SCENE: PackedScene = preload("res://scenes/world/spawn_marker.tscn")
const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/enemy_projectile.tscn")
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")
const ARENA_SCENE: PackedScene = preload("res://scenes/world/arena.tscn")
const ARENA_RECT: Rect2 = Rect2(-1000, -650, 2000, 1300)
const TEST_PATH: String = "user://test_boss_phases.json"
const SETTLE_FRAMES: int = 10

var _player: Player
var _manager: WaveManager
var _numbers: ObjectPool
var _changes: Array[int] = []


func before_each() -> void:
	GameState.difficulty = null
	GameState.start_run(13)
	_changes.clear()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.debug_invulnerable = true
	var container: Node2D = Node2D.new()
	add_child_autofree(container)
	for pair: Array in [[MARKER_SCENE, Pools.SPAWN_MARKERS], [ENEMY_PROJECTILE_SCENE, Pools.ENEMY_PROJECTILES], [DAMAGE_NUMBER_SCENE, Pools.DAMAGE_NUMBERS]]:
		var pool: ObjectPool = ObjectPool.new()
		pool.scene = pair[0]
		pool.group_name = pair[1]
		add_child_autofree(pool)
		if pair[1] == Pools.DAMAGE_NUMBERS:
			_numbers = pool
	_manager = WaveManager.new()
	add_child_autofree(_manager)
	_manager.start(_player, ARENA_RECT, container)
	Events.boss_phase_changed.connect(_on_phase_changed)


func after_each() -> void:
	Events.boss_phase_changed.disconnect(_on_phase_changed)
	GameState.difficulty = null
	get_tree().paused = false


func _on_phase_changed(_enemy: Enemy, index: int) -> void:
	_changes.append(index)


func _enemy(id: String) -> Enemy:
	return _manager.spawn_enemy(load("res://data/enemies/%s.tres" % id), Vector2(500, 300), 1.0)


func _hit(enemy: Enemy, amount: int) -> void:
	enemy.take_damage(DamageInfo.create(amount, false, 0.0, null))


func _phased_enemies() -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for res: Resource in DataRegistry.get_all("enemies"):
		if (res as EnemyData).behavior is PhasedData:
			result.append(res as EnemyData)
	return result


func test_every_phase_has_name_in_both_languages() -> void:
	var enemies: Array[EnemyData] = _phased_enemies()
	assert_eq(enemies.size(), 5, "3 Elites + 2 Bosse")
	var locale: String = TranslationServer.get_locale()
	for enemy: EnemyData in enemies:
		var phases: Array[BossPhaseData] = (enemy.behavior as PhasedData).phases
		assert_eq(phases[0].aura_color.a, 0.0, "Phase 1 ohne Aura: " + String(enemy.id))
		for index: int in phases.size():
			var key: String = phases[index].name_key
			assert_ne(key, "", "%s Phase %d" % [enemy.id, index + 1])
			for lang: String in ["de", "en"]:
				TranslationServer.set_locale(lang)
				assert_ne(tr(key), key, "%s (%s)" % [key, lang])
			if index > 0:
				assert_gt(phases[index].aura_color.a, 0.0, "Aura ab Phase 2: " + String(enemy.id))
	TranslationServer.set_locale(locale)


func test_hp_transition_emits_signal_and_grants_invulnerability() -> void:
	var boss: Enemy = _enemy("finsternis")
	var behavior: PhasedBehavior = boss.phased_behavior()
	assert_false(boss.is_invulnerable())
	_hit(boss, roundi(boss.max_hp * 0.3))
	await wait_physics_frames(2)
	assert_eq(behavior.phase_index, 1, "unter 75 % HP")
	assert_eq(_changes, [1] as Array[int])
	assert_true(boss.is_invulnerable(), "kurz unverwundbar")
	var hp_before: float = boss.hp
	_hit(boss, 1000)
	assert_eq(boss.hp, hp_before, "kein Schaden während der Unverwundbarkeit")
	await wait_seconds(PHASES.invulnerable_time + 0.15)
	assert_false(boss.is_invulnerable(), "nach 0,5 s wieder verwundbar")
	_hit(boss, 1000)
	assert_eq(boss.hp, hp_before - 1000)


func test_immune_text_is_throttled() -> void:
	var boss: Enemy = _enemy("dimmer")
	_hit(boss, roundi(boss.max_hp * 0.55))
	await wait_physics_frames(2)
	assert_true(boss.is_invulnerable())
	var before: int = _numbers.active_count()
	for i: int in 20:
		_hit(boss, 10)
	assert_eq(_numbers.active_count() - before, 1, "20 Treffer im selben Moment: ein 'Immun'")
	var label: Label = (_numbers.get_active().back() as DamageNumber).get_node("Label") as Label
	assert_eq(label.text, tr("IMMUNE_TEXT"))
	assert_eq(label.label_settings.font_color, PHASES.immune_text_color)


func test_time_transition_and_timer() -> void:
	var elite: Enemy = _enemy("schattenweber")
	var behavior: PhasedBehavior = elite.phased_behavior()
	assert_almost_eq(behavior.time_to_next(), 25.0, 0.1)
	behavior.set("_phase_time", 24.9)
	await wait_physics_frames(10)
	assert_eq(behavior.phase_index, 1)
	assert_eq(_changes, [1] as Array[int])
	assert_eq(behavior.time_to_next(), -1.0, "letzte Phase: kein Timer")
	var boss: Enemy = _enemy("dimmer")
	assert_eq(boss.phased_behavior().time_to_next(), -1.0, "Boss wechselt nur nach HP")


func test_aura_follows_phase() -> void:
	var boss: Enemy = _enemy("finsternis")
	var sprite: Sprite2D = boss.get_node("Visual/Sprite") as Sprite2D
	var flash: Material = sprite.material
	_hit(boss, roundi(boss.max_hp * 0.3))
	await wait_physics_frames(2)
	var aura: ShaderMaterial = sprite.material as ShaderMaterial
	assert_ne(aura, flash, "Aura-Material ab Phase 2")
	assert_eq(aura.get_shader_parameter(Enemy.BUFF_OUTLINE_PARAM), boss.phased_behavior().current_phase().aura_color)


func test_boss_bar_markers_phase_text_and_timer() -> void:
	var boss: Enemy = _enemy("finsternis")
	var bar: BossBar = BossBar.new()
	add_child_autofree(bar)
	bar.setup(boss)
	assert_eq(bar.marker_count(), 2, "Finsternis: 75 % und 40 %")
	assert_eq(bar.phase_text(), tr("HUD_BOSS_PHASE") % [1, 3, tr("PHASE_NAME_ENEMY_FINSTERNIS_1")])
	assert_eq(bar.timer_text(), "", "kein Zeitwechsel")
	_hit(boss, roundi(boss.max_hp * 0.7))
	await wait_physics_frames(2)
	bar.refresh()
	assert_eq(bar.phase_text(), tr("HUD_BOSS_PHASE") % [2, 3, tr("PHASE_NAME_ENEMY_FINSTERNIS_2")])

	var golem: Enemy = _enemy("kolbengolem")
	var golem_bar: BossBar = BossBar.new()
	add_child_autofree(golem_bar)
	golem_bar.setup(golem)
	assert_eq(golem_bar.marker_count(), 1)
	assert_eq(golem_bar.timer_text(), tr("HUD_PHASE_TIMER") % 25)


func test_lexicon_lists_phase_names_and_triggers() -> void:
	var data: EnemyData = load("res://data/enemies/kolbengolem.tres")
	var text: String = Lexicon._phases_text(data.behavior as PhasedData)
	assert_string_contains(text, tr("PHASE_NAME_ENEMY_KOLBENGOLEM_1"))
	assert_string_contains(text, tr("PHASE_NAME_ENEMY_KOLBENGOLEM_2"))
	assert_string_contains(text, tr("LEX_PHASE_UNTIL_HP_TIME") % [60, "25"])


func test_double_boss_hud_has_two_compact_bars_and_banner() -> void:
	SaveManager.use_path(TEST_PATH)
	SaveManager.reset()
	GameState.character = load("res://data/characters/standardbirne.tres")
	GameState.difficulty = load("res://data/difficulties/spannung_5.tres")
	GameState.start_run(5)
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	arena.player.debug_invulnerable = true
	arena.wave_manager.admin_jump_to_wave(20)
	var hud: Hud = arena.get_node("Hud") as Hud
	var frames: int = 0
	while hud.boss_bars().size() < 2 and frames < 600:
		await get_tree().physics_frame
		frames += 1
	var bars: Array[BossBar] = hud.boss_bars()
	assert_eq(bars.size(), 2, "zwei Bosse auf Spannung 5")
	for bar: BossBar in bars:
		assert_true(bar.is_compact())
		assert_gt(bar.marker_count(), 0)
	var boss: Enemy = bars[0].enemy
	boss.take_damage(DamageInfo.create(roundi(boss.max_hp * 0.62), false, 0.0, null))
	await wait_physics_frames(3)
	await get_tree().process_frame
	var phase: BossPhaseData = boss.phased_behavior().current_phase()
	assert_eq(hud.phase_banner_text(), tr("PHASE_BANNER") % [2, tr(phase.name_key)])
	GameState.character = null
	GameState.difficulty = null
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	SaveManager.use_path("user://test_save.json")
	SaveManager.reset()
