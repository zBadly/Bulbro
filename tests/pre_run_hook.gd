extends GutHookScript
## Läuft vor allen Tests: Spielstand auf eine eigene Testdatei umleiten, damit Tests nie den echten Spielstand verändern.

const TEST_SAVE_PATH: String = "user://test_save.json"


func run() -> void:
	SaveManager.use_path(TEST_SAVE_PATH)
	SaveManager.reset()
