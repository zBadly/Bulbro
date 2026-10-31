extends GutTest
## Startwaffen je Charakter (Phase 15, Paket 9): Listen, Hinweise, gespeicherte Wahl, Auswahl-Layout und "Nochmal".

const RUN_SETUP_SCENE: PackedScene = preload("res://scenes/ui/run_setup.tscn")
## Listen aus docs/PHASE_15.md, Paket 9, mit den Tauschen nach der Simulator-Prüfung (Reihenfolge = Kartenreihenfolge).
const EXPECTED: Dictionary[StringName, Array] = {
	&"standardbirne": [&"funkenpistole", &"glasscherbe", &"kabelpeitsche", &"funkenfaust"],
	&"gluehfaden_boxer": [&"funkenfaust", &"lampenhammer"],
	&"neonroehre": [&"glasscherbe", &"taschenlampenstrahl", &"kristallstab"],
	&"led_schuetze": [&"funkenpistole", &"laserpointer", &"batterie_schleuder", &"prisma"],
	&"lavalampe": [&"taschenlampenstrahl", &"blitzwerfer", &"voodoo_nadel", &"kristallstab"],
	&"taschenlampe": [&"schraubenzieher", &"loetkolben"],
	&"discokugel": [&"funkenpistole", &"prisma", &"laserpointer"],
	&"lichterkette": [&"funkenpistole", &"glasscherbe", &"laserpointer"],
	&"halogenstrahler": [&"lampenhammer", &"leuchtrakete", &"taschenlampenstrahl"],
	&"nachtlicht": [&"heilstrahl", &"dornenranke"],
	&"blitzlicht": [&"funkenfaust", &"glasscherbe", &"lampenhammer"],
	&"kerze": [&"ast", &"batterie_schleuder", &"dornenranke"],
	&"irrlicht": [&"seelenlaterne", &"gluehwuermchen_stab"],
	&"zuendkerze": [&"feuerzeugwerfer", &"blitzwerfer"],
	&"kronleuchter": [&"kristallstab", &"blitzwerfer", &"taschenlampenstrahl"],
	&"schwarzlicht": [&"voodoo_nadel", &"blitzwerfer"],
	&"gewaechshauslampe": [&"dornenranke", &"kabelpeitsche", &"heilstrahl"],
	&"smartbulb": [&"funkenpistole", &"leuchtrakete", &"laserpointer"],
	&"drohnenleuchte": [&"schraubenzieher", &"funkenpistole"],
	&"stroboskop": [&"laserpointer", &"prisma", &"taschenlampenstrahl"],
	&"vampirbirne": [&"glasscherbe", &"kabelpeitsche", &"funkenfaust"],
	&"spiegelkugel": [&"prisma", &"funkenpistole", &"laserpointer"],
}


func before_each() -> void:
	SaveManager.reset()
	GameState.character = null
	GameState.starting_weapon = null
	GameState.setup_character = null
	GameState.setup_weapon = null


func after_all() -> void:
	SaveManager.reset()


func _char(id: StringName) -> CharacterData:
	return load("res://data/characters/%s.tres" % id)


func test_lists_match_spec_and_restrictions() -> void:
	assert_eq(EXPECTED.size(), Unlocks.all_characters().size())
	for character: CharacterData in Unlocks.all_characters():
		var ids: Array[StringName] = []
		for weapon: WeaponData in character.starting_weapons:
			ids.append(weapon.id)
			assert_true(character.can_use_weapon(weapon), "%s darf %s nicht tragen" % [character.id, weapon.id])
		assert_eq(ids, EXPECTED[character.id], String(character.id))


func test_every_start_weapon_has_hint_in_both_languages() -> void:
	var de: Translation = TranslationServer.get_translation_object("de")
	var en: Translation = TranslationServer.get_translation_object("en")
	for character: CharacterData in Unlocks.all_characters():
		assert_eq(character.start_weapon_hints.size(), character.starting_weapons.size(), String(character.id))
		for weapon: WeaponData in character.starting_weapons:
			var key: String = character.start_weapon_hint(weapon)
			assert_ne(key, "", "%s/%s ohne Hinweis" % [character.id, weapon.id])
			assert_ne(String(de.get_message(key)), "", key + " (de)")
			assert_ne(String(en.get_message(key)), "", key + " (en)")


func test_weak_combinations_are_described_honestly() -> void:
	# Keine Versprechen: schwächere Kombinationen nennen, was fehlt.
	TranslationServer.set_locale("de")
	var boxer: CharacterData = _char(&"gluehfaden_boxer")
	for weapon: WeaponData in boxer.starting_weapons.slice(1):
		assert_string_contains(tr(boxer.start_weapon_hint(weapon)), "Kein Unbewaffnet-Bonus")
	var lamp: CharacterData = _char(&"taschenlampe")
	assert_string_contains(tr(lamp.start_weapon_hint(lamp.starting_weapons[1])), "Kein Strom-Bonus")
	var neon: CharacterData = _char(&"neonroehre")
	for weapon: WeaponData in neon.starting_weapons.slice(1):
		assert_string_contains(tr(neon.start_weapon_hint(weapon)), "Strom startet bei 0")


func test_saved_choice_and_fallback() -> void:
	var lava: CharacterData = _char(&"lavalampe")
	assert_eq(SaveManager.get_start_weapon(lava.id), &"")
	assert_eq(lava.find_starting_weapon(SaveManager.get_start_weapon(lava.id)).id, &"taschenlampenstrahl")
	SaveManager.set_start_weapon(lava.id, &"kristallstab")
	assert_eq(SaveManager.get_start_weapon(lava.id), &"kristallstab")
	assert_eq(lava.find_starting_weapon(&"kristallstab").id, &"kristallstab")
	# Gespeicherte Waffe nicht (mehr) in der Liste: erste Startwaffe
	assert_eq(lava.find_starting_weapon(&"funkenpistole").id, &"taschenlampenstrahl")
	SaveManager.load_game()
	assert_eq(SaveManager.get_start_weapon(lava.id), &"kristallstab", "bleibt nach dem Laden erhalten")


func test_old_save_gets_start_weapons_field() -> void:
	var migrated: Dictionary = SaveManager._migrate({"version": 2, "progress": {"characters": ["kerze"]}})
	assert_true(migrated["progress"].has("start_weapons"))
	assert_eq(migrated["progress"]["characters"], ["kerze"])


func _open_weapon_step(character_id: StringName) -> RunSetup:
	GameState.character = _char(character_id)
	var setup: RunSetup = RUN_SETUP_SCENE.instantiate()
	add_child_autofree(setup)
	setup.call("_confirm_character")
	return setup


func _cards(setup: RunSetup) -> Array[OfferCard]:
	var cards: Array[OfferCard] = []
	for node: Node in setup.find_children("*", "OfferCard", true, false):
		cards.append(node as OfferCard)
	return cards


func test_weapon_step_preselects_saved_weapon() -> void:
	SaveManager.set_start_weapon(&"led_schuetze", &"prisma")
	var setup: RunSetup = _open_weapon_step(&"led_schuetze")
	await wait_process_frames(2)
	var cards: Array[OfferCard] = _cards(setup)
	assert_eq(cards.size(), 4)
	var focused: Control = setup.get_viewport().gui_get_focus_owner()
	assert_not_null(focused)
	assert_eq((cards[3].first_button()), focused, "Prisma vorausgewählt")


func test_cards_have_same_size_for_two_and_four_weapons() -> void:
	var four: RunSetup = _open_weapon_step(&"standardbirne")
	await wait_process_frames(2)
	var size_four: Vector2 = _cards(four)[0].size
	for card: OfferCard in _cards(four):
		assert_eq(card.size, size_four)
	var two: RunSetup = _open_weapon_step(&"taschenlampe")
	await wait_process_frames(2)
	for card: OfferCard in _cards(two):
		assert_eq(card.size, size_four, "Karten springen nicht mit der Anzahl")


func test_tooltip_uses_character_values_without_run_line() -> void:
	var setup: RunSetup = _open_weapon_step(&"gluehfaden_boxer")
	await wait_process_frames(2)
	var previews: Array[Player] = setup.get("_previews")
	assert_eq(previews.size(), 2, "ein Vorschau-Spieler je Startwaffe")
	var fist: Weapon = previews[0].weapon_slots.get_weapons()[0]
	assert_lt(fist.get_cooldown(), fist.get_tier_stats().cooldown, "+50 % Unbewaffnet-Angriffstempo im Tooltip")
	var text: String = TooltipText.weapon(fist, false)
	assert_false(text.contains(TextFormat.t("TIP_RUN").get_slice("%", 0)), "keine Run-Zeile")
	# Vorschau zählt nicht als Spieler im Run
	assert_false(previews[0].is_in_group(Player.GROUP))
	var cards: Array[OfferCard] = _cards(setup)
	cards[1].first_button().grab_focus()
	await wait_process_frames(2)
	assert_string_contains(GameTooltip.current_text(), tr(previews[1].weapon_slots.get_weapons()[0].data.name_key))
	setup.call("_show_step", RunSetup.Step.CHARACTER)
	await wait_process_frames(2)
	assert_eq((setup.get("_previews") as Array).size(), 0, "Vorschau-Spieler werden beim Verlassen freigegeben")


func test_retry_uses_setup_even_after_admin_switch() -> void:
	var lava: CharacterData = _char(&"lavalampe")
	var crystal: WeaponData = lava.find_starting_weapon(&"kristallstab")
	GameState.set_run_setup(lava, crystal, load("res://data/difficulties/spannung_0.tres"))
	GameState.character = _char(&"kerze")
	GameState.restore_run_setup()
	assert_eq(GameState.character, lava)
	assert_eq(GameState.starting_weapon, crystal)
