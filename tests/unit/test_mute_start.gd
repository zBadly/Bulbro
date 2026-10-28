extends GutTest
## Stummer Start (--mute / BULBRO_MUTE=1) für Läufe mit Fenster: nur Master-Bus stumm, gespeicherte Lautstärken bleiben.


func after_each() -> void:
	SaveManager.force_mute = false
	SaveManager.apply_options()


func test_resolve_mute() -> void:
	assert_false(SaveManager.resolve_mute([], ""), "normaler Start mit Ton")
	assert_false(SaveManager.resolve_mute(["0", "--save=user://x.json"], ""), "fremde Argumente ändern nichts")
	assert_false(SaveManager.resolve_mute([], "0"))
	assert_true(SaveManager.resolve_mute([SaveManager.MUTE_ARG], ""))
	assert_true(SaveManager.resolve_mute(["--save=user://x.json", SaveManager.MUTE_ARG], ""))
	assert_true(SaveManager.resolve_mute([], "1"))


func test_force_mute_mutes_master_without_changing_volumes() -> void:
	var master: int = AudioServer.get_bus_index(SaveManager.MASTER_BUS)
	SaveManager.set_volume(SaveManager.MASTER_BUS, 0.8)
	var music_before: float = SaveManager.get_volume("Music")
	SaveManager.force_mute = true
	SaveManager.apply_options()
	assert_true(AudioServer.is_bus_mute(master), "Master stumm")
	assert_eq(SaveManager.get_volume(SaveManager.MASTER_BUS), 0.8, "gespeicherte Lautstärke unverändert")
	assert_eq(SaveManager.get_volume("Music"), music_before)
	SaveManager.set_volume(SaveManager.MASTER_BUS, 0.6)
	assert_true(AudioServer.is_bus_mute(master), "auch nach Änderung in den Optionen stumm")
	SaveManager.force_mute = false
	SaveManager.apply_options()
	assert_false(AudioServer.is_bus_mute(master), "ohne Schalter wieder Ton")
