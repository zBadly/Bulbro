extends GutTest
## Prüft, dass GUT läuft und die Autoloads registriert sind.


func test_gut_runs() -> void:
	assert_true(true, "GUT ist eingerichtet")


func test_autoloads_exist() -> void:
	for autoload_name: String in ["Events", "GameState", "DataRegistry", "SaveManager", "AudioManager"]:
		assert_not_null(get_tree().root.get_node_or_null(autoload_name), "Autoload fehlt: " + autoload_name)


func test_run_seed_is_reproducible() -> void:
	GameState.start_run(1234)
	var first: int = GameState.rng.randi()
	GameState.start_run(1234)
	assert_eq(GameState.rng.randi(), first, "Gleicher Seed muss gleiche Zufallsfolge liefern")
