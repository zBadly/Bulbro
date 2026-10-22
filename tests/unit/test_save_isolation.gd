extends GutTest
## Tests, Headless-Checks und Werkzeuge dürfen nie den echten Spielstand des Spielers verwenden.

const CUSTOM_PATH: String = "user://check_save.json"
const ENV_PATH: String = "user://env_save.json"


func test_tests_never_run_on_the_real_save() -> void:
	assert_false(SaveManager.is_real_save(), "Testlauf nutzt einen eigenen Spielstand")
	assert_ne(SaveManager.save_path, SaveManager.SAVE_PATH)
	assert_ne(ProjectSettings.globalize_path(SaveManager.save_path), ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func test_headless_start_uses_separate_save() -> void:
	assert_eq(SaveManager.resolve_path([], "", true), SaveManager.HEADLESS_SAVE_PATH, "Headless-Check ohne Angabe")
	assert_ne(SaveManager.HEADLESS_SAVE_PATH, SaveManager.SAVE_PATH)


func test_normal_start_uses_real_save() -> void:
	assert_eq(SaveManager.resolve_path([], "", false), SaveManager.SAVE_PATH, "Spielstart mit Bildschirm")
	assert_eq(SaveManager.resolve_path(["0", "--apply"], "", false), SaveManager.SAVE_PATH, "fremde Argumente ändern nichts")


func test_argument_and_environment_override() -> void:
	var args: PackedStringArray = ["0", SaveManager.SAVE_ARG_PREFIX + CUSTOM_PATH]
	assert_eq(SaveManager.resolve_path(args, ENV_PATH, false), CUSTOM_PATH, "Argument vor Umgebungsvariable")
	assert_eq(SaveManager.resolve_path(args, "", true), CUSTOM_PATH, "Argument auch headless")
	assert_eq(SaveManager.resolve_path([], ENV_PATH, false), ENV_PATH)
	assert_eq(SaveManager.resolve_path([], ENV_PATH, true), ENV_PATH)
	assert_eq(SaveManager.resolve_path([SaveManager.SAVE_ARG_PREFIX], "", true), SaveManager.HEADLESS_SAVE_PATH, "leeres Argument wird ignoriert")
