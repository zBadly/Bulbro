extends GutTest
## Regression Phase 15/1: Bosssieg in Welle 20 darf die Run-Auswertung nicht abbrechen.
## Ursache war ein ungetyptes "{}" im Ternär von Unlocks.make_context, sobald end_run() den Run beendet hatte.

const TEST_PATH: String = "user://test_boss_victory.json"
const ARENA_SCENE: PackedScene = preload("res://scenes/world/arena.tscn")
const DISCOKUGEL_CHALLENGE: ChallengeData = preload("res://data/challenges/unlock_discokugel.tres")
const SETTLE_FRAMES: int = 10
const MAX_KILL_FRAMES: int = 600


func before_each() -> void:
	SaveManager.use_path(TEST_PATH)
	SaveManager.reset()
	GameState.character = null
	GameState.starting_weapon = null
	GameState.difficulty = null


func after_each() -> void:
	get_tree().paused = false
	GameState.character = null
	GameState.starting_weapon = null
	GameState.difficulty = null
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	SaveManager.use_path("user://test_save.json")
	SaveManager.reset()


## Gleiche Reihenfolge wie Arena._on_run_won: erst end_run, dann Auswertung im Run-Ende-Bildschirm.
func test_evaluation_after_end_run_completes_challenges() -> void:
	GameState.start_run(15)
	GameState.run_stats.primitive_only = true
	GameState.total_sparks_collected = int(DISCOKUGEL_CHALLENGE.value)
	GameState.end_run(true)
	var completed: Array[ChallengeData] = Unlocks.evaluate_run_end(true)
	assert_not_null(completed, "Auswertung lief durch")
	assert_true(SaveManager.is_character_unlocked(&"kerze"), "Siegbedingung geprüft")
	assert_true(SaveManager.is_character_unlocked(&"discokugel"), "Gesamtwert zählt nach Run-Ende voll")
	assert_eq(SaveManager.get_stat(SaveManager.STAT_RUNS), 1)


func test_context_outside_run_uses_saved_totals() -> void:
	GameState.start_run(16)
	GameState.total_sparks_collected = 120
	GameState.end_run(false)
	Unlocks.evaluate_run_end(false)
	var ctx: ChallengeContext = Unlocks.make_context(false, false)
	assert_eq(ctx.totals.get(DISCOKUGEL_CHALLENGE.total_key(), -1), 120, "weder doppelt noch abgezogen")


## Integration: Arena mit Spiegelbild-Charakter auf Spannung 5 (beide Bosse), Welle 20 springen, Bosse töten.
func test_boss_kill_in_arena_shows_victory() -> void:
	GameState.character = load("res://data/characters/spiegelkugel.tres")
	GameState.difficulty = load("res://data/difficulties/spannung_5.tres")
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	arena.player.debug_invulnerable = true
	arena.wave_manager.jump_to_wave(arena.wave_manager.get_wave_count())
	var frames: int = 0
	while arena.wave_manager.state != WaveManager.State.FINISHED and frames < MAX_KILL_FRAMES:
		for enemy: Enemy in arena.wave_manager._active.duplicate():
			if enemy.is_alive():
				enemy.die()
		await get_tree().physics_frame
		frames += 1
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	assert_eq(arena.wave_manager.state, WaveManager.State.FINISHED, "Bosswelle beendet")
	assert_true(arena.get_node("GameOver").visible, "Siegbildschirm sichtbar")
	assert_true(GameState.run_reported, "Run gemeldet")
	assert_true(SaveManager.is_challenge_completed(&"win_spiegelkugel"), "Sieg-Challenge ausgewertet")
	assert_eq(SaveManager.get_won_difficulties(&"spiegelkugel"), [5])
