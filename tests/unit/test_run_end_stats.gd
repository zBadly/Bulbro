extends GutTest
## Phase 15, Paket 5: Run-Statistik (Kampfzeit, DPS seit dem ersten Treffer, Schaden je Welle), Tabelle mit
## Sortierung und MVP, Run-Historie im Spielstand und der Run-Ende-Bildschirm mit Reitern.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CONFIG: RunStatsConfig = preload("res://data/config/run_stats_config.tres")
const AST: StringName = &"weapon/ast"
const SUPERNOVA: StringName = &"item/supernova"
## Basisauflösung minus Rand des Run-Ende-Bildschirms.
const SCREEN_SIZE: Vector2 = Vector2(1920, 1080)

var _locale: String


func before_each() -> void:
	SaveManager.reset()
	GameState.start_run(77)
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("de")


func after_each() -> void:
	get_tree().paused = false
	TranslationServer.set_locale(_locale)
	SaveManager.reset()


# --- Kampfzeit und DPS ---

func test_combat_time_counts_only_waves() -> void:
	var run: RunStats = RunStats.new()
	run.begin_wave()
	run.advance(10.0)
	run.end_wave()
	run.advance(50.0)
	assert_almost_eq(run.combat_time(), 10.0, 0.001, "Shop und Pausen zählen nicht")
	run.begin_wave()
	run.advance(5.0)
	assert_almost_eq(run.combat_time(), 15.0, 0.001, "laufende Welle zählt mit")


func test_dps_counts_from_first_hit() -> void:
	var run: RunStats = RunStats.new()
	run.begin_wave()
	run.advance(10.0)
	run.record_damage(AST, 100)
	run.end_wave()
	run.begin_wave()
	run.advance(30.0)
	run.record_damage(SUPERNOVA, 300)
	run.advance(10.0)
	run.end_wave()
	assert_almost_eq(run.first_hit_time[AST], 0.0 + 10.0, 0.001)
	assert_almost_eq(run.first_hit_time[SUPERNOVA], 40.0, 0.001, "erste Welle 10 s + 30 s in der zweiten")
	assert_almost_eq(run.dps_of(AST, CONFIG.min_dps_time), 100.0 / 40.0, 0.001)
	assert_almost_eq(run.dps_of(SUPERNOVA, CONFIG.min_dps_time), 300.0 / 10.0, 0.001, "spät gekauft wirkt nicht schwach")


func test_dps_uses_minimum_time() -> void:
	var run: RunStats = RunStats.new()
	run.begin_wave()
	run.record_damage(AST, 50)
	assert_almost_eq(run.dps_of(AST, 1.0), 50.0, 0.001)
	assert_eq(run.dps_of(&"weapon/unbekannt", 1.0), 0.0)


func test_wave_damage_is_derived_from_source_damage() -> void:
	var run: RunStats = RunStats.new()
	run.begin_wave()
	run.record_damage(AST, 40)
	run.record_damage(SUPERNOVA, 60)
	run.end_wave()
	run.begin_wave()
	run.record_damage(AST, 250)
	run.end_wave()
	assert_eq(run.wave_damage, [100, 250] as Array[int])
	assert_eq(run.total_damage(), 350)


func test_begin_wave_closes_open_wave() -> void:
	var run: RunStats = RunStats.new()
	run.begin_wave()
	run.advance(3.0)
	run.begin_wave()
	assert_eq(run.wave_times.size(), 1, "Admin-Sprung ohne Wellenende")


func test_wave_events_and_death_mid_wave() -> void:
	Events.wave_started.emit(1)
	GameState.run_stats.advance(12.0)
	Events.enemy_damaged.emit(AST, 80)
	GameState.end_run(false)
	assert_eq(GameState.run_stats.wave_times.size(), 1, "Tod schließt die Welle ab")
	assert_almost_eq(GameState.run_stats.wave_times[0], 12.0, 0.001)
	assert_eq(GameState.run_stats.wave_damage, [80] as Array[int])


func test_roundtrip_through_json() -> void:
	var run: RunStats = RunStats.new()
	run.begin_wave()
	run.advance(7.5)
	run.record_damage(AST, 10)
	run.record_kill(AST)
	run.damage_taken = 33
	run.dodges = 4
	run.sparks_spent = 120
	run.rerolls = 6
	run.end_wave()
	var copy: RunStats = RunStats.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	assert_almost_eq(copy.first_hit_time[AST], 7.5, 0.001)
	assert_eq(copy.wave_times.size(), 1)
	assert_almost_eq(copy.wave_times[0], 7.5, 0.001)
	assert_eq(copy.wave_damage, [10] as Array[int])
	assert_eq([copy.damage_taken, copy.dodges, copy.sparks_spent, copy.rerolls], [33, 4, 120, 6])
	assert_almost_eq(copy.dps_of(AST, CONFIG.min_dps_time), run.dps_of(AST, CONFIG.min_dps_time), 0.001)


func test_run_save_keeps_run_id_and_first_hits() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	GameState.run_stats.begin_wave()
	GameState.run_stats.advance(4.0)
	GameState.run_stats.record_damage(AST, 9)
	GameState.run_stats.end_wave()
	var run_id: String = GameState.run_id
	var data: Dictionary = JSON.parse_string(JSON.stringify(RunSave.capture(player)))
	GameState.start_run(5)
	RunSave.restore_state(data)
	assert_eq(GameState.run_id, run_id)
	assert_almost_eq(GameState.run_stats.first_hit_time[AST], 4.0, 0.001)


# --- Erfassung im Spiel ---

func test_spend_counts_sparks_spent() -> void:
	GameState.add_sparks(50)
	assert_true(GameState.spend(30))
	assert_false(GameState.spend(100), "zu teuer zählt nicht")
	assert_eq(GameState.run_stats.sparks_spent, 30)


func test_hits_count_damage_taken_and_dodges() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var dodged: Array[int] = [0]
	player.dodged.connect(func() -> void: dodged[0] += 1)
	var taken: int = 0
	player.stats.add_modifier(StatModifier.create(Stats.DODGE, 50.0))
	player.stats.add_modifier(StatModifier.create(Stats.MAX_HP, 10000.0))
	player.current_hp = player.get_max_hp()
	for i: int in 40:
		player._invulnerable_left = 0.0
		taken += player.take_hit(5.0)
	assert_gt(dodged[0], 0, "einige Treffer ausgewichen")
	assert_eq(GameState.run_stats.dodges, dodged[0])
	assert_eq(GameState.run_stats.damage_taken, taken)


# --- Tabelle ---

func _sample_run() -> RunStats:
	var run: RunStats = RunStats.new()
	run.begin_wave()
	run.advance(10.0)
	run.record_damage(AST, 600)
	run.record_damage(SUPERNOVA, 300)
	run.record_damage(DamageSource.ally(), 100)
	for i: int in 3:
		run.record_kill(SUPERNOVA)
	run.record_kill(AST)
	run.end_wave()
	return run


func test_rows_share_and_default_sort() -> void:
	var rows: Array[RunReport.Row] = RunReport.rows(_sample_run())
	assert_eq(rows.size(), 3)
	assert_eq(rows[0].origin, AST, "Standard: Schaden absteigend")
	assert_almost_eq(rows[0].share, 0.6, 0.001)
	assert_almost_eq(rows[1].share + rows[2].share, 0.4, 0.001)
	assert_eq(RunReport.mvp(rows), AST)


func test_sort_by_columns() -> void:
	var rows: Array[RunReport.Row] = RunReport.rows(_sample_run())
	RunReport.sort_rows(rows, RunReport.Column.KILLS, true)
	assert_eq(rows[0].origin, SUPERNOVA)
	RunReport.sort_rows(rows, RunReport.Column.DAMAGE, false)
	assert_eq(rows[0].origin, DamageSource.ally())
	RunReport.sort_rows(rows, RunReport.Column.KIND, false)
	assert_eq(rows.map(func(r: RunReport.Row) -> String: return r.kind), ["weapon", "item", "ally"])


func test_source_names() -> void:
	assert_eq(RunReport.source_name(AST), tr("WEAPON_AST"))
	assert_eq(RunReport.source_name(DamageSource.ally()), tr("RUN_STATS_KIND_ALLY"))
	assert_eq(RunReport.source_name(DamageSource.structure(&"lampenturm")), tr("STRUCTURE_LAMPENTURM"))
	assert_eq(RunReport.source_name(DamageSource.character(&"zuendkerze")), tr("CHAR_ZUENDKERZE"))
	assert_not_null(RunReport.source_icon(AST))


func test_number_formats() -> void:
	assert_eq(RunReport.format_int(1234567), "1.234.567")
	assert_eq(RunReport.format_int(999), "999")
	assert_eq(RunReport.format_percent(0.1234), "12,3 %")
	assert_eq(RunReport.format_dps(12.34), "12,3")
	assert_eq(RunReport.format_dps(1234.4), "1.234")
	assert_eq(RunReport.format_time(125.0), "2:05")
	TranslationServer.set_locale("en")
	assert_eq(RunReport.format_int(1234567), "1,234,567")
	assert_eq(RunReport.format_percent(0.1234), "12.3 %")


# --- Run-Historie ---

func test_history_is_limited_and_newest_first() -> void:
	for i: int in CONFIG.history_size + 5:
		SaveManager.record_run_history({"id": "run_%d" % i}, CONFIG.history_size)
	var history: Array[Dictionary] = SaveManager.get_run_history()
	assert_eq(history.size(), CONFIG.history_size)
	assert_eq(history[0]["id"], "run_%d" % (CONFIG.history_size + 4))


func test_run_end_records_history_entry() -> void:
	GameState.run_stats = _sample_run()
	GameState.end_run(false)
	Unlocks.evaluate_run_end(false)
	var history: Array[Dictionary] = SaveManager.get_run_history()
	assert_eq(history.size(), 1)
	var entry: Dictionary = history[0]
	assert_eq(entry["id"], GameState.run_id)
	assert_eq(entry["character"], String(GameState.character.id))
	assert_eq(entry["result"], RunHistory.RESULT_DEFEAT)
	assert_eq(entry["top_sources"].size(), CONFIG.history_top_sources)
	assert_eq(entry["top_sources"][0]["source"], String(AST))
	assert_eq(entry["top_sources"][0]["damage"], 600)
	assert_true(entry.has("date") and entry.has("difficulty") and entry.has("wave"))


func test_endless_updates_same_entry() -> void:
	GameState.current_wave = 20
	GameState.end_run(true)
	Unlocks.evaluate_run_end(true)
	GameState.endless = true
	GameState.endless_start_wave = 20
	GameState.current_wave = 27
	GameState.end_run(false)
	Unlocks.evaluate_run_end(false)
	var history: Array[Dictionary] = SaveManager.get_run_history()
	assert_eq(history.size(), 1, "derselbe Run, kein zweiter Eintrag")
	assert_eq(history[0]["result"], RunHistory.RESULT_VICTORY, "Tod im Endlos-Modus bleibt ein Sieg")
	assert_eq(history[0]["endless_wave"], 7)


func test_admin_run_is_not_recorded() -> void:
	GameState.admin.used = true
	GameState.end_run(true)
	Unlocks.evaluate_run_end(true)
	assert_eq(SaveManager.get_run_history().size(), 0)


func test_history_survives_reload() -> void:
	SaveManager.record_run_history({"id": "a"}, CONFIG.history_size)
	SaveManager.save_game()
	SaveManager.load_game()
	assert_eq(SaveManager.get_run_history().size(), 1)


# --- Run-Ende-Bildschirm ---

func _show_screen(victory: bool) -> GameOverScreen:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var screen: GameOverScreen = GameOverScreen.new()
	add_child_autofree(screen)
	screen.show_result(victory, GameState.current_wave, player)
	return screen


func test_screen_tabs_and_sorting() -> void:
	GameState.run_stats = _sample_run()
	var screen: GameOverScreen = _show_screen(false)
	assert_eq(screen.tab, GameOverScreen.Tab.OVERVIEW)
	assert_false(screen.stats_panel.visible)
	screen.show_tab(GameOverScreen.Tab.STATS)
	assert_true(screen.stats_panel.visible)
	var panel: RunStatsPanel = screen.stats_panel
	assert_eq(panel.row_buttons.size(), 3)
	assert_eq(panel.mvp_origin, AST)
	panel.sort_by(RunReport.Column.KILLS)
	assert_eq(panel.rows[0].origin, SUPERNOVA)
	panel.sort_by(RunReport.Column.KILLS)
	assert_false(panel.descending, "zweiter Klick kehrt um")
	panel.cycle_sort()
	assert_eq(panel.sort_column, RunReport.Column.SHARE)
	# Beim Umsortieren ersetzte Zeilen werden mit queue_free freigegeben.
	await wait_physics_frames(1)


func test_screen_fits_base_resolution() -> void:
	var run: RunStats = _sample_run()
	for i: int in 40:
		run.record_damage(DamageSource.item(StringName("dummy_%d" % i)), i + 1)
	for i: int in 60:
		run.wave_damage.append(i * 10)
	GameState.run_stats = run
	var screen: GameOverScreen = _show_screen(true)
	screen.show_tab(GameOverScreen.Tab.STATS)
	await wait_physics_frames(2)
	var limit: Vector2 = SCREEN_SIZE - Vector2.ONE * GameOverScreen.MARGIN * 2
	var box: Control = screen.stats_panel.get_parent().get_parent() as Control
	var needed: Vector2 = box.get_combined_minimum_size()
	assert_lte(needed.x, limit.x, "Breite passt")
	assert_lte(needed.y, limit.y, "Höhe passt (Tabelle scrollt)")


func test_endless_death_shows_endless_wave() -> void:
	GameState.endless = true
	GameState.endless_start_wave = 20
	GameState.current_wave = 24
	var screen: GameOverScreen = _show_screen(false)
	var texts: Array[String] = []
	for label: Node in screen.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, tr("REACHED_ENDLESS_WAVE") % [4, 24])
	assert_has(texts, tr("RUN_STATS_ENDLESS_WAVE") % [4, 24])
