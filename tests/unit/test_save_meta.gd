extends GutTest
## Tests für Speichern/Laden, Migration, Challenges, gesperrte Items und "Run fortsetzen" (Phase 12).

const TEST_PATH: String = "user://test_save_meta.json"
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _completed: Array[ChallengeData] = []


func before_each() -> void:
	SaveManager.use_path(TEST_PATH)
	SaveManager.reset()
	GameState.character = null
	GameState.difficulty = null
	GameState.start_run(77)
	_completed.clear()
	Events.challenge_completed.connect(_on_completed)


func after_each() -> void:
	Events.challenge_completed.disconnect(_on_completed)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	SaveManager.use_path("user://test_save.json")
	SaveManager.reset()


func _on_completed(challenge: ChallengeData) -> void:
	_completed.append(challenge)


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


# --- Speichern und Laden ---
func test_save_and_load_roundtrip() -> void:
	SaveManager.unlock_character(&"kerze")
	SaveManager.unlock_item(&"supernova")
	SaveManager.record_win(&"standardbirne", 3)
	SaveManager.record_win(&"standardbirne", 1)
	SaveManager.add_stat(SaveManager.STAT_KILLS, 250)
	SaveManager.set_option(SaveManager.SCREENSHAKE_KEY, false)
	SaveManager.save_game()
	SaveManager.reset()
	assert_false(SaveManager.is_character_unlocked(&"kerze"), "reset leert den Speicher")
	SaveManager.load_game()
	assert_true(SaveManager.is_character_unlocked(&"kerze"))
	assert_true(SaveManager.is_item_unlocked(&"supernova"))
	assert_eq(SaveManager.get_won_difficulties(&"standardbirne"), [1, 3])
	assert_eq(SaveManager.get_stat(SaveManager.STAT_KILLS), 250)
	assert_eq(SaveManager.get_stat(SaveManager.STAT_WINS), 2)
	assert_false(SaveManager.get_option(SaveManager.SCREENSHAKE_KEY, true))
	assert_eq(SaveManager.get_version(), SaveManager.SAVE_VERSION)
	assert_false(FileAccess.file_exists(TEST_PATH + SaveManager.TEMP_SUFFIX), "keine Temp-Datei übrig")


func test_file_is_versioned_json() -> void:
	SaveManager.save_game()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed["version"]), SaveManager.SAVE_VERSION)


func test_migrates_version_one() -> void:
	var old: Dictionary = {"version": 1, "options": {"locale": "en"}, "progress": {"characters": ["kerze"], "wins_kerze": 2}}
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	SaveManager.load_game()
	assert_eq(SaveManager.get_version(), SaveManager.SAVE_VERSION)
	assert_true(SaveManager.is_character_unlocked(&"kerze"))
	assert_eq(SaveManager.get_wins(&"kerze"), 1, "alte Siege als gewonnen übernommen")
	assert_eq(SaveManager.get_option(SaveManager.LOCALE_KEY), "en")
	assert_false(SaveManager.has_run())


func test_corrupt_file_starts_fresh() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{kaputt")
	file.close()
	SaveManager.load_game()
	assert_eq(SaveManager.get_stat(SaveManager.STAT_RUNS), 0)


func test_assist_factor_is_clamped() -> void:
	SaveManager.set_option(SaveManager.ENEMY_HP_KEY, 10.0)
	assert_eq(SaveManager.get_assist_factor(SaveManager.ENEMY_HP_KEY), 0.25)
	SaveManager.set_option(SaveManager.ENEMY_HP_KEY, 60.0)
	assert_almost_eq(SaveManager.get_assist_factor(SaveManager.ENEMY_HP_KEY), 0.6, 0.001)
	assert_eq(SaveManager.get_assist_factor(SaveManager.ENEMY_SPEED_KEY), 1.0, "Standard 100 %")


# --- Challenges ---
func test_every_locked_character_has_a_challenge() -> void:
	for character: CharacterData in Unlocks.all_characters():
		if not character.unlocked_by_default:
			assert_not_null(Unlocks.challenge_for(character), String(character.id))
	assert_eq(Unlocks.all_challenges().size(), 19)


func test_live_challenge_unlocks_and_emits() -> void:
	assert_false(Unlocks.is_unlocked(load("res://data/characters/taschenlampe.tres")))
	GameState.max_structures = 3
	Unlocks.check(false, false)
	assert_true(Unlocks.is_unlocked(load("res://data/characters/taschenlampe.tres")))
	assert_eq(_completed.size(), 1)
	Unlocks.check(false, false)
	assert_eq(_completed.size(), 1, "nicht doppelt")


func test_victory_challenges_only_at_run_end() -> void:
	GameState.run_stats.primitive_only = true
	Unlocks.check(false, false)
	assert_false(SaveManager.is_character_unlocked(&"kerze"))
	Unlocks.evaluate_run_end(true)
	assert_true(SaveManager.is_character_unlocked(&"kerze"))
	assert_true(SaveManager.is_item_unlocked(&"sonnenkollektor"), "Sieg mit Standardbirne")
	assert_eq(SaveManager.get_won_difficulties(&"standardbirne"), [0])
	assert_eq(SaveManager.get_stat(SaveManager.STAT_RUNS), 1)


func test_locked_items_are_not_offered() -> void:
	var supernova: ItemData = load("res://data/items/supernova.tres")
	assert_false(Unlocks.is_item_unlocked(supernova))
	assert_false(supernova in Shop.create_from_registry().items)
	SaveManager.unlock_item(&"supernova")
	assert_true(supernova in Shop.create_from_registry().items)
	assert_true(Unlocks.is_item_unlocked(load("res://data/items/kernreaktor.tres")), "Tier IV bleibt verfügbar")


# --- Run fortsetzen ---
func test_run_save_roundtrip() -> void:
	var player: Player = _player()
	player.apply_character(GameState.character)
	player.weapon_slots.add_weapon(load("res://data/weapons/prisma.tres"), 3)
	player.weapon_slots.add_weapon(load("res://data/weapons/ast.tres"), 1)
	for id: String in ["ersatzsicherung", "ersatzsicherung", "tesla_spule"]:
		var item: ItemData = load("res://data/items/%s.tres" % id)
		GameState.add_item(item)
		player.apply_item(item)
	player.add_run_modifier(StatModifier.create(Stats.DAMAGE_PCT, 12.0))
	GameState.current_wave = 7
	GameState.add_sparks(123)
	GameState.add_xp(30.0)
	GameState.special_waves[11] = WaveManager.SPECIAL_ELITE
	var ctx: ShopContext = ShopContext.from_run(player)
	GameState.shop.open_shop(ctx)
	GameState.shop.toggle_lock(2)
	player.take_hit(4.0)
	var saved: Dictionary = RunSave.capture(player)
	var expected_hp: float = player.current_hp
	var expected_max: float = player.get_max_hp()
	var next_roll: int = GameState.rng.randi()

	var json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	RunSave.restore_state(json)
	var copy: Player = _player()
	RunSave.apply_to_player(json, copy)
	assert_eq(GameState.current_wave, 7)
	assert_eq(GameState.sparks, 123)
	assert_eq(GameState.level, saved["level"])
	assert_eq(GameState.special_waves[11], WaveManager.SPECIAL_ELITE)
	assert_eq(GameState.items.size(), 3)
	assert_eq(copy.triggers.size(), 1, "Tesla-Spule wieder registriert")
	assert_eq(copy.get_max_hp(), expected_max)
	assert_eq(copy.current_hp, expected_hp)
	assert_eq(copy.stats.get_stat(Stats.DAMAGE_PCT), player.stats.get_stat(Stats.DAMAGE_PCT))
	var tiers: Array = copy.weapon_slots.get_weapons().map(func(w: Weapon) -> int: return w.tier)
	assert_eq(tiers, [3, 1])
	assert_true(GameState.shop.offers[2].locked)
	assert_eq(GameState.shop.offers.size(), 4)
	assert_eq(GameState.rng.randi(), next_roll, "Zufall läuft identisch weiter")
	var offers_before: Array = GameState.shop.offers.duplicate()
	GameState.shop.open_shop(ShopContext.from_run(copy))
	assert_eq(GameState.shop.offers, offers_before, "erster Shop nach dem Laden bleibt unverändert")


func test_save_run_persists_and_clears() -> void:
	SaveManager.save_run({"wave": 4, "character": "kerze"})
	SaveManager.load_game()
	assert_true(SaveManager.has_run())
	assert_eq(int(SaveManager.load_run()["wave"]), 4)
	SaveManager.clear_run()
	SaveManager.load_game()
	assert_false(SaveManager.has_run())
