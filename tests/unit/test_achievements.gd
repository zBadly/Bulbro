extends GutTest
## Achievements und Gesamtstatistik (Phase 15, Paket 9): Daten, Erreichbarkeit, Prüfung, Admin-Sperre,
## rückwirkende Gutschrift, Sammlungen, Popup-Stapel, Statistik-Bildschirm und Lexikon-Reiter.

const TEST_PATH: String = "user://test_achievements.json"
const STATS_SCENE: PackedScene = preload("res://scenes/ui/stats_screen.tscn")
const ACHIEVEMENT_COUNT: int = 45
const IRRLICHT: CharacterData = preload("res://data/characters/irrlicht.tres")
const TOWERS: TowerConfig = preload("res://data/config/tower_config.tres")
const SHOP: ShopConfig = preload("res://data/config/shop_config.tres")
## Zähler, die nicht aus GameState.run_totals kommen, sondern direkt am Run-Ende gezählt werden.
const SAVE_ONLY_STATS: PackedStringArray = ["runs", "wins"]

var _completed: Array[ChallengeData] = []


func before_each() -> void:
	SaveManager.use_path(TEST_PATH)
	SaveManager.reset()
	GameState.character = null
	GameState.difficulty = null
	GameState.start_run(91)
	_completed.clear()
	Events.challenge_completed.connect(_on_completed)


func after_each() -> void:
	Events.challenge_completed.disconnect(_on_completed)
	GameState.is_run_active = false
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	SaveManager.use_path("user://test_save.json")
	SaveManager.reset()


func _on_completed(challenge: ChallengeData) -> void:
	_completed.append(challenge)


func _achievement(id: String) -> AchievementData:
	for achievement: AchievementData in Unlocks.all_achievements():
		if achievement.id == StringName("ach_" + id):
			return achievement
	return null


func _completed_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for challenge: ChallengeData in _completed:
		ids.append(challenge.id)
	return ids


# --- Daten ---

func test_all_achievements_are_complete() -> void:
	var all: Array[AchievementData] = Unlocks.all_achievements()
	assert_eq(all.size(), ACHIEVEMENT_COUNT)
	var ids: Dictionary[StringName, bool] = {}
	var orders: Dictionary[int, bool] = {}
	for achievement: AchievementData in all:
		var context: String = String(achievement.id)
		assert_false(ids.has(achievement.id), "eindeutige ID: " + context)
		assert_false(orders.has(achievement.order), "eindeutige Reihenfolge: " + context)
		ids[achievement.id] = true
		orders[achievement.order] = true
		assert_not_null(achievement.icon, "Icon: " + context)
		assert_ne(tr(achievement.name_key), achievement.name_key, "Name übersetzt: " + context)
		assert_ne(tr(achievement.description_key), achievement.description_key, "Beschreibung übersetzt: " + context)
		assert_false(achievement.condition_text().contains("{"), "alle Platzhalter ersetzt: " + context)
		assert_null(achievement.reward_character, "keine Belohnung: " + context)
		assert_null(achievement.reward_item, "keine Belohnung: " + context)


func test_every_category_is_used() -> void:
	for category: int in AchievementData.Category.size():
		var count: int = Unlocks.all_achievements().filter(func(a: AchievementData) -> bool: return a.category == category).size()
		assert_gt(count, 0, "Kategorie %d hat Achievements" % category)


func test_endless_texts_use_total_wave_with_endless_number() -> void:
	assert_eq(_achievement("kein_ende").condition_text(), tr("ACH_KEIN_ENDE_DESC").format({"value": "25", "endless": 5}))
	assert_true(_achievement("dauerlicht").condition_text().contains("50"))
	assert_true(_achievement("dauerlicht").condition_text().contains("30"), "Endlos 30")
	assert_true(_achievement("zyklusbrecher").condition_text().contains("30"), "erster Boss-Zyklus in Welle 30")


func test_progress_text_groups_thousands() -> void:
	assert_eq(_achievement("lichtflut").progress_text(6053.0), "6.053/10.000")
	assert_eq(_achievement("erster_funke").progress_text(0.0), "", "Ziel 1 ohne Zahlenfortschritt")


# --- Erreichbarkeit ---

func test_total_stats_are_counted_somewhere() -> void:
	var run: RunStats = GameState.run_stats
	run.cursed_kills = 1
	run.elite_kills = 1
	run.record_enemy_kill(&"motte")
	run.record_kill(DamageSource.structure(&"stolperdraht"))
	var keys: Array[String] = GameState.run_totals().keys()
	for achievement: AchievementData in Unlocks.all_achievements():
		if achievement.condition == ChallengeData.Condition.TOTAL_STAT:
			assert_true(achievement.stat_key in keys or achievement.stat_key in SAVE_ONLY_STATS,
				"Statistik wird gezählt: %s (%s)" % [achievement.id, achievement.stat_key])


func test_run_values_exist_in_run_stats() -> void:
	var run: RunStats = RunStats.new()
	for achievement: AchievementData in Unlocks.all_achievements():
		if achievement.condition == ChallengeData.Condition.RUN_VALUE:
			var value: Variant = run.get(achievement.stat_key)
			assert_true(value is int or value is float, "RunStats-Feld: %s (%s)" % [achievement.id, achievement.stat_key])


func test_collection_targets_match_data() -> void:
	var uniques: int = 0
	for res: Resource in DataRegistry.get_all("items"):
		if (res as ItemData).is_unique():
			uniques += 1
	var phases: int = 0
	var bosses: Array[StringName] = []
	for res: Resource in DataRegistry.get_all("enemies"):
		var enemy: EnemyData = res as EnemyData
		if enemy.is_boss:
			bosses.append(enemy.id)
			phases += (enemy.behavior as PhasedData).phases.size()
	var targets: Dictionary[String, int] = {
		GameState.COLLECTION_UNIQUES: uniques,
		GameState.COLLECTION_PETS: DataRegistry.get_all("pets").size(),
		GameState.COLLECTION_BOSS_PHASES: phases,
		GameState.COLLECTION_BOSSES: bosses.size(),
	}
	for achievement: AchievementData in Unlocks.all_achievements():
		if achievement.condition != ChallengeData.Condition.COLLECTION:
			continue
		assert_true(targets.has(achievement.stat_key), "bekannte Sammlung: " + String(achievement.id))
		assert_lte(achievement.value, float(targets.get(achievement.stat_key, 0)), "Ziel erreichbar: " + String(achievement.id))
		if achievement.entry != &"":
			assert_true(achievement.entry in bosses, "Boss existiert: " + String(achievement.id))
	assert_eq(_achievement("kuriositaetenkabinett").value, float(uniques), "alle Einzigartigen")
	assert_eq(_achievement("zoohandlung").value, float(DataRegistry.get_all("pets").size()), "alle Begleiter")
	assert_eq(_achievement("phasenwandler").value, float(phases), "alle Boss-Phasen")


func test_character_and_difficulty_targets_match_data() -> void:
	var characters: int = Unlocks.all_characters().size()
	assert_eq(_achievement("lampenfamilie").value, float(characters))
	assert_eq(_achievement("sammlerstueck").value, float(characters))
	assert_lte(_achievement("vielseitig").value, float(characters))
	var levels: Array[int] = []
	for res: Resource in DataRegistry.get_all("difficulties"):
		levels.append((res as DifficultyData).level)
	assert_eq(_achievement("spannungsbogen").value, float(levels.size()))
	assert_true(int(_achievement("volle_spannung").value) in levels)


func test_run_value_targets_are_reachable() -> void:
	assert_eq(_achievement("festung").value, float(TOWERS.max_towers), "Obergrenze der Türme")
	assert_lte(_achievement("baumeister").value, float(TOWERS.max_towers))
	assert_eq(_achievement("treue_seele").value, float(WeaponData.MAX_TIER))
	var max_slots: int = 0
	for character: CharacterData in Unlocks.all_characters():
		max_slots = maxi(max_slots, character.weapon_slots)
	assert_lte(_achievement("klassenbester").value, float(max_slots))
	assert_lte(_achievement("unberuehrt").value, float(Lexicon.endless_wave(0)), "Welle im normalen Run")
	# Einzigartige: höchstens eins je Shop, Shops ab unique_min_wave bis zur letzten Welle vor dem Boss
	assert_lte(_achievement("goldrausch").value, float(Lexicon.endless_wave(0) - SHOP.unique_min_wave))
	assert_gt(_achievement("dauerlicht").value, float(Lexicon.endless_wave(0)))
	assert_gt(_achievement("kurzer_prozess").value, 0.0)


func _reanimate() -> ReanimateEffect:
	for candidate: ItemEffect in IRRLICHT.effects:
		if candidate is ReanimateEffect:
			return candidate
	return null


## Geisterheer zählt Kills der Schattengeister (Herkunft "ally") in einem Run.
func test_ghost_army_counts_ally_kills() -> void:
	assert_eq(_achievement("geisterheer").stat_key, "ally_kills")
	var ghost_kill: DamageInfo = DamageInfo.create(10, false, 0.0, null, DamageSource.ally())
	var weapon_kill: DamageInfo = DamageInfo.create(10, false, 0.0, null, DamageSource.weapon(&"ast"))
	for i: int in 3:
		Events.enemy_killed.emit(load("res://data/enemies/motte.tres"), Vector2.ZERO, ghost_kill)
	Events.enemy_killed.emit(load("res://data/enemies/motte.tres"), Vector2.ZERO, weapon_kill)
	assert_eq(GameState.run_stats.ally_kills, 3)
	GameState.run_stats.ally_kills = int(_achievement("geisterheer").value)
	Unlocks.check(false, false)
	assert_true(SaveManager.is_challenge_completed(&"ach_geisterheer"))


## Irrlicht: alle `interval` Sekunden ein Geist, der `lifetime` Sekunden lebt; die Texte nennen die erreichbare Zahl.
func test_ghost_texts_name_reachable_limit() -> void:
	var effect: ReanimateEffect = _reanimate()
	var possible: int = mini(effect.max_allies, ceili(effect.lifetime / effect.interval))
	assert_eq(effect.max_at_once(), possible)
	assert_lt(possible, effect.max_allies, "Grenze im Effekt ist nicht erreichbar, Texte dürfen sie nicht nennen")
	var text: String = effect.describe()[0]
	assert_true(text.contains(" %d " % possible), "Effekttext nennt %d: %s" % [possible, text])
	assert_false(text.contains(" %d " % effect.max_allies), "Effekttext nennt nicht die unerreichbare Grenze")
	assert_eq(Lexicon.max_allies_at_once(), possible, "Lexikon-Thema Verbündete")
	assert_true(Lexicon.topic_text("LEX_TOPIC_ALLIES_TEXT").contains(" %d " % possible))


func test_elites_appear_on_some_difficulty() -> void:
	var elite_waves: int = 0
	for res: Resource in DataRegistry.get_all("difficulties"):
		elite_waves += (res as DifficultyData).special_wave_pairs.size()
	assert_gt(elite_waves, 0, "Elitejäger braucht Elitewellen")


func test_tower_kill_ids_cover_all_tower_items() -> void:
	for res: Resource in DataRegistry.get_all("items"):
		var item: ItemData = res as ItemData
		for effect: ItemEffect in item.effects:
			if effect is TowerItemEffect:
				assert_true((effect as TowerItemEffect).structure.id in TOWERS.tower_kill_ids, "Turm-Kills zählen: " + String(item.id))
	assert_false(&"drohne" in TOWERS.tower_kill_ids, "Drohnen sind keine Türme")


# --- Prüfung ---

func test_total_achievement_completes_and_admin_blocks() -> void:
	SaveManager.add_stat(SaveManager.STAT_KILLS, 999)
	GameState.run_stats.enemies_killed = 1
	GameState.admin.used = true
	Unlocks.check(false, false)
	assert_false(SaveManager.is_challenge_completed(&"ach_schattenjaeger"), "Admin-Run zählt nicht")
	GameState.admin.used = false
	Unlocks.check(false, false)
	assert_true(SaveManager.is_challenge_completed(&"ach_schattenjaeger"))
	assert_true(&"ach_schattenjaeger" in _completed_ids(), "Popup gemeldet")
	assert_gt(SaveManager.get_completed_date(&"ach_schattenjaeger"), 0, "Datum gespeichert")


func test_run_value_achievement_and_best_value() -> void:
	GameState.run_stats.max_hit = 400
	Unlocks.check(false, false)
	assert_false(SaveManager.is_challenge_completed(&"ach_volltreffer"))
	assert_eq(SaveManager.get_challenge_best(&"ach_volltreffer"), 400.0, "Bestwert gemerkt")
	assert_eq(Unlocks.progress(_achievement("volltreffer")), 400.0)
	GameState.run_stats.max_hit = 1000
	Unlocks.check(false, false)
	assert_true(SaveManager.is_challenge_completed(&"ach_volltreffer"))


func test_victory_conditions_only_at_run_end() -> void:
	GameState.run_stats.max_weapons = 2
	Unlocks.check(false, false)
	assert_false(SaveManager.is_challenge_completed(&"ach_sparsam"))
	assert_false(SaveManager.is_challenge_completed(&"ach_minimalist"))
	Unlocks.check(true, true)
	assert_true(SaveManager.is_challenge_completed(&"ach_sparsam"), "Sieg ohne Reroll")
	assert_true(SaveManager.is_challenge_completed(&"ach_minimalist"), "Sieg mit 2 Waffen")


func test_rerolls_and_weapons_block_victory_achievements() -> void:
	GameState.run_stats.rerolls = 1
	GameState.run_stats.max_weapons = 3
	Unlocks.check(true, true)
	assert_false(SaveManager.is_challenge_completed(&"ach_sparsam"))
	assert_false(SaveManager.is_challenge_completed(&"ach_minimalist"))


func test_clean_wave_needs_no_damage() -> void:
	var run: RunStats = GameState.run_stats
	run.begin_wave()
	run.end_wave(10)
	assert_eq(run.best_clean_wave, 10)
	run.begin_wave()
	run.damage_taken += 3
	run.end_wave(11)
	assert_eq(run.best_clean_wave, 10, "Welle mit Schaden zählt nicht")
	run.begin_wave()
	run.end_wave()
	assert_eq(run.best_clean_wave, 10, "Tod (ohne Wellennummer) zählt nicht")


func test_boss_collection_saved_at_run_end_but_not_in_admin_runs() -> void:
	GameState.run_stats.add_to_collection(GameState.COLLECTION_BOSSES, &"dimmer")
	GameState.run_stats.record_boss_kill(25.0)
	Unlocks.check(false, false)
	assert_true(SaveManager.is_challenge_completed(&"ach_dimmer_gedimmt"), "Boss im Run besiegt")
	assert_true(SaveManager.is_challenge_completed(&"ach_kurzer_prozess"), "Boss in 25 s")
	GameState.end_run(true)
	Unlocks.evaluate_run_end(true)
	assert_true(SaveManager.collection_has(GameState.COLLECTION_BOSSES, &"dimmer"))
	assert_eq(SaveManager.get_record(SaveManager.RECORD_BOSS_KILL), 25.0)
	assert_gt(SaveManager.get_record(SaveManager.RECORD_WIN_TIME % 0), -1.0)
	GameState.start_run(92)
	GameState.admin.used = true
	GameState.run_stats.add_to_collection(GameState.COLLECTION_BOSSES, &"finsternis")
	GameState.end_run(true)
	Unlocks.evaluate_run_end(true)
	assert_false(SaveManager.collection_has(GameState.COLLECTION_BOSSES, &"finsternis"), "Admin-Run speichert nichts")


func test_unique_items_fill_collection_and_run_maximum() -> void:
	var uniques: Array[ItemData] = []
	for res: Resource in DataRegistry.get_all("items"):
		if (res as ItemData).is_unique() and uniques.size() < 3:
			uniques.append(res as ItemData)
	for item: ItemData in uniques:
		GameState.add_item(item)
	assert_eq(GameState.run_stats.max_uniques, 3)
	Unlocks.check(false, false)
	assert_true(SaveManager.is_challenge_completed(&"ach_goldstueck"))
	assert_true(SaveManager.is_challenge_completed(&"ach_goldrausch"))
	assert_false(SaveManager.is_challenge_completed(&"ach_kuriositaetenkabinett"))
	assert_eq(Unlocks.progress(_achievement("kuriositaetenkabinett")), 0.0, "außerhalb des Runs zählt nur der Spielstand")


func test_tower_kills_ignore_drones() -> void:
	var run: RunStats = GameState.run_stats
	run.record_kill(DamageSource.structure(&"flammenturm"))
	run.record_kill(DamageSource.structure(&"stolperdraht"))
	run.record_kill(DamageSource.structure(&"drohne"))
	assert_eq(GameState.run_totals()[SaveManager.STAT_TOWER_KILLS], 2)


func test_endless_run_counts_totals_once() -> void:
	GameState.run_stats.record_enemy_kill(&"motte")
	GameState.run_stats.play_time = 65.0
	Unlocks.evaluate_run_end(true)
	Unlocks.evaluate_run_end(false)
	assert_eq(SaveManager.get_stat(SaveManager.ENEMY_KILLS_PREFIX + "motte"), 1)
	assert_eq(SaveManager.get_stat(SaveManager.STAT_PLAY_TIME), 65)
	assert_eq(MetaStats.character_runs(GameState.character.id), 1, "Run je Charakter einmal")


func test_run_stats_roundtrip_keeps_achievement_values() -> void:
	var run: RunStats = GameState.run_stats
	run.max_hit = 321
	run.max_frozen = 12
	run.fastest_boss_kill = 41.5
	run.record_purchase(&"ast")
	run.add_to_collection(GameState.COLLECTION_PETS, &"igel")
	var copy: RunStats = RunStats.from_dict(run.to_dict())
	assert_eq(copy.max_hit, 321)
	assert_eq(copy.max_frozen, 12)
	assert_eq(copy.fastest_boss_kill, 41.5)
	assert_eq(copy.purchases.get(&"ast", 0), 1)
	assert_true(copy.collection_has(GameState.COLLECTION_PETS, &"igel"))


# --- Rückwirkende Gutschrift ---

func _fill_old_save() -> void:
	SaveManager.add_stat(SaveManager.STAT_KILLS, 6053)
	SaveManager.add_stat(SaveManager.STAT_RUNS, 5)
	SaveManager.add_stat(SaveManager.STAT_TOTAL_SPARKS, 6963)
	SaveManager.add_stat(SaveManager.STAT_CRYSTALS, 26)
	SaveManager.add_stat(SaveManager.weapon_kills_key(&"laserpointer"), 4368)
	SaveManager.record_win(&"led_schuetze", 0)
	SaveManager.record_run_history({"id": "a", "character": "led_schuetze", "difficulty": 0, "result": RunHistory.RESULT_VICTORY,
		"wave": 20, "endless_wave": 0, "boss_cycles": 0, "date": 1793000000, "time": 1210.0, "level": 30, "kills": 3100,
		"top_sources": [{"source": "weapon/laserpointer", "damage": 90000, "kills": 2500}]}, 20)


func test_backfill_credits_existing_save_once() -> void:
	_fill_old_save()
	var credited: Array[ChallengeData] = Unlocks.backfill_achievements()
	var ids: Array[StringName] = []
	for challenge: ChallengeData in credited:
		ids.append(challenge.id)
	for expected: StringName in [&"ach_erster_funke", &"ach_schattenjaeger", &"ach_hell_erleuchtet", &"ach_massenvernichtung"]:
		assert_true(expected in ids, "rückwirkend: " + String(expected))
	for not_yet: StringName in [&"ach_lichtflut", &"ach_funkensammler", &"ach_volle_spannung", &"ach_kein_ende", &"ach_dimmer_gedimmt"]:
		assert_false(not_yet in ids, "noch nicht: " + String(not_yet))
	assert_eq(_completed.size(), credited.size(), "jedes gutgeschriebene Achievement meldet ein Popup")
	assert_eq(Unlocks.progress(_achievement("lichtflut")), 6053.0)
	assert_eq(SaveManager.get_record(SaveManager.RECORD_WIN_TIME % 0), 1210.0, "Bestzeit aus der Historie")
	assert_eq(MetaStats.favorite_weapon(&"led_schuetze").id, &"laserpointer", "Lieblingswaffe aus der Historie")
	assert_true(Unlocks.backfill_achievements().is_empty(), "nur einmal")


func test_backfill_on_fresh_save_does_nothing() -> void:
	assert_true(Unlocks.backfill_achievements().is_empty())
	assert_true(SaveManager.is_achievements_backfilled())


func test_endless_backfill_uses_total_wave() -> void:
	SaveManager.record_endless_best(&"standardbirne", 5)
	var ids: Array[StringName] = []
	for challenge: ChallengeData in Unlocks.backfill_achievements():
		ids.append(challenge.id)
	assert_true(&"ach_kein_ende" in ids, "Endlos 5 = Welle 25")
	assert_false(&"ach_dauerlicht" in ids)
	assert_eq(Unlocks.progress(_achievement("dauerlicht")), 25.0)


# --- Oberfläche ---

func test_toasts_stack_and_queue() -> void:
	var toast: UnlockToast = UnlockToast.new()
	add_child_autofree(toast)
	for achievement: AchievementData in Unlocks.all_achievements().slice(0, 6):
		Events.challenge_completed.emit(achievement)
	assert_eq(toast.visible_count(), UnlockToast.MAX_VISIBLE, "stapeln sich")
	assert_eq(toast.queued_count(), 6 - UnlockToast.MAX_VISIBLE, "der Rest wartet")


func test_stats_screen_builds_every_tab() -> void:
	_fill_old_save()
	SaveManager.complete_challenge(&"ach_erster_funke")
	var screen: StatsScreen = STATS_SCENE.instantiate()
	add_child_autofree(screen)
	for tab: int in StatsScreen.TAB_KEYS.size():
		screen.show_tab(tab)
		assert_eq(screen.current_tab(), tab)
	screen.show_tab(StatsScreen.Tab.HISTORY)
	assert_eq(screen.history_button_count(), 1)
	screen.show_tab(StatsScreen.Tab.ACHIEVEMENTS)
	var list: AchievementList = screen.get_achievement_list()
	assert_eq(list.row_count(), ACHIEVEMENT_COUNT)
	list.set_category(AchievementData.Category.BOSSES)
	assert_eq(list.row_count(), 4, "Filter Bosse")


func test_meta_stats_rows() -> void:
	_fill_old_save()
	SaveManager.add_stat(SaveManager.CHARACTER_RUNS_PREFIX + "led_schuetze", 2)
	assert_eq(MetaStats.favorite_character().id, &"led_schuetze")
	assert_eq(MetaStats.weapon_kills(&"laserpointer"), 4368, "alte Waffen-Kills zählen")
	assert_eq(MetaStats.character_rows().size(), Unlocks.all_characters().size() + 1)
	assert_eq(MetaStats.enemy_rows().size(), DataRegistry.get_all("enemies").size() + 1)
	assert_eq(MetaStats.format_play_time(3900), TextFormat.t("META_HOURS_MINUTES") % [1, 5])


func test_lexicon_has_achievement_tab() -> void:
	SaveManager.complete_challenge(&"ach_erster_funke")
	var entries: Array[LexiconEntry] = Lexicon.entries(Lexicon.Tab.ACHIEVEMENTS)
	assert_eq(entries.size(), ACHIEVEMENT_COUNT)
	for entry: LexiconEntry in entries:
		assert_false(entry.locked, "nie verborgen")
		assert_eq(entry.dimmed, entry.id != &"ach_erster_funke", "offene gedämpft")
