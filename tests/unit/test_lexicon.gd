extends GutTest
## Lexikon: jede Resource hat einen vollständigen Eintrag ohne leere Felder, Texte kommen aus denselben
## Funktionen wie die Shop-Tooltips, Suche und Filter wirken, das Layout springt beim Auswählen nicht.

const LEXICON_SCENE: PackedScene = preload("res://scenes/ui/lexicon.tscn")
## Kategorie der DataRegistry je Reiter.
const TAB_CATEGORIES: Dictionary[int, String] = {
	Lexicon.Tab.CHARACTERS: "characters", Lexicon.Tab.WEAPONS: "weapons", Lexicon.Tab.ITEMS: "items",
	Lexicon.Tab.ENEMIES: "enemies", Lexicon.Tab.CLASSES: "sets", Lexicon.Tab.MECHANICS: "lexicon",
}
const LORE_CATEGORIES: PackedStringArray = ["characters", "weapons", "items", "enemies", "sets", "difficulties", "lexicon"]
## Unübersetzter Schlüssel (z. B. LORE_ITEM_LUPE) oder nicht gefüllter Platzhalter.
const KEY_PATTERN: String = "\\b[A-Z][A-Z0-9]*_[A-Z0-9_]+\\b"
const PLACEHOLDER_PATTERN: String = "%[sd]"


func _assert_translated(key: String, context: String) -> void:
	assert_ne(key, "", "Schlüssel fehlt: " + context)
	assert_ne(TextFormat.t(key), key, "Übersetzung fehlt: %s (%s)" % [key, context])


func test_every_resource_has_an_entry() -> void:
	for tab: int in TAB_CATEGORIES:
		var entries: Array[LexiconEntry] = Lexicon.entries(tab)
		var resources: Array[Resource] = DataRegistry.get_all(TAB_CATEGORIES[tab])
		assert_gt(resources.size(), 0, TAB_CATEGORIES[tab])
		assert_eq(entries.size(), resources.size(), "ein Eintrag pro Resource: " + TAB_CATEGORIES[tab])
		for entry: LexiconEntry in entries:
			assert_true(entry.source in resources, "Eintrag stammt aus der DataRegistry: " + entry.title)


func test_entries_have_no_empty_fields() -> void:
	var key_regex: RegEx = RegEx.create_from_string(KEY_PATTERN)
	var placeholder_regex: RegEx = RegEx.create_from_string(PLACEHOLDER_PATTERN)
	for tab: int in Lexicon.tab_count():
		for entry: LexiconEntry in Lexicon.entries(tab):
			var context: String = "%s/%s" % [Lexicon.tab_title(tab), entry.id]
			assert_ne(entry.title.strip_edges(), "", "Name: " + context)
			assert_ne(entry.subtitle.strip_edges(), "", "Einordnung: " + context)
			assert_ne(entry.lore.strip_edges(), "", "Spruch: " + context)
			assert_ne(entry.lock_text.strip_edges() if tab in [Lexicon.Tab.CHARACTERS, Lexicon.Tab.ITEMS] else "-", "", "Freischaltung: " + context)
			assert_not_null(entry.icon, "Icon: " + context)
			assert_gt(entry.sections.size(), 0, "Abschnitte: " + context)
			var texts: PackedStringArray = [entry.title, entry.subtitle, entry.lore]
			for section: LexiconSection in entry.sections:
				assert_false(section.is_empty(), "leerer Abschnitt '%s': %s" % [section.title, context])
				texts.append(section.plain_text())
			var all_text: String = Lexicon.strip_bbcode(" ".join(texts))
			assert_null(key_regex.search(all_text), "unübersetzter Schlüssel in %s: %s" % [context, all_text])
			assert_null(placeholder_regex.search(all_text), "offener Platzhalter in " + context)


func test_resources_have_lore_and_lexicon_texts() -> void:
	for category: String in LORE_CATEGORIES:
		for res: Resource in DataRegistry.get_all(category):
			_assert_translated(res.get("lore_text"), "%s/%s" % [category, res.resource_path.get_file()])
	for res: Resource in DataRegistry.get_all("characters"):
		_assert_translated((res as CharacterData).tip_key, "Tipp " + res.resource_path.get_file())
	for res: Resource in DataRegistry.get_all("enemies"):
		var enemy: EnemyData = res as EnemyData
		_assert_translated(enemy.behavior_key, "Verhalten " + String(enemy.id))
		_assert_translated(enemy.counter_key, "Konter " + String(enemy.id))
		var phased: PhasedData = enemy.behavior as PhasedData
		if phased != null:
			for phase: BossPhaseData in phased.phases:
				_assert_translated(phase.description_key, "Phase " + String(enemy.id))
	for res: Resource in DataRegistry.get_all("items"):
		for tag: StringName in (res as ItemData).tags:
			_assert_translated(Lexicon.tag_key(tag), "Tag " + String(tag))


func test_mechanics_explain_every_stat_once() -> void:
	var covered: Array[StringName] = []
	for res: Resource in DataRegistry.get_all("lexicon"):
		for stat: StringName in (res as LexiconTopicData).stats:
			assert_false(stat in covered, "Stat doppelt erklärt: " + String(stat))
			assert_true(Stats.is_valid(stat), "unbekannter Stat: " + String(stat))
			covered.append(stat)
	for stat: StringName in Stats.all():
		assert_true(stat in covered, "Stat ohne Erklärung: " + String(stat))
		_assert_translated("STAT_INFO_" + String(stat).to_upper(), String(stat))


func test_effect_texts_come_from_shop_functions() -> void:
	for entry: LexiconEntry in Lexicon.entries(Lexicon.Tab.ITEMS):
		var item: ItemData = entry.source as ItemData
		assert_eq(entry.sections[0].text, item.get_description(), "Item-Effekte wie im Shop: " + entry.title)
	for entry: LexiconEntry in Lexicon.entries(Lexicon.Tab.WEAPONS):
		var weapon: WeaponData = entry.source as WeaponData
		var specials: String = Lexicon.strip_bbcode(entry.sections[entry.sections.size() - 1].text)
		for line: String in TextFormat.weapon_special_lines(weapon, WeaponData.MIN_TIER):
			assert_true(specials.contains(Lexicon.strip_bbcode(line)), "Besonderheit wie im Shop: %s (%s)" % [entry.title, line])
	for entry: LexiconEntry in Lexicon.entries(Lexicon.Tab.CHARACTERS):
		var character: CharacterData = entry.source as CharacterData
		var stats: String = TextFormat.describe_character_stats(character)
		assert_eq(entry.sections[0].text, stats if stats != "" else TextFormat.t("LEX_NONE"), "Charakter-Stats: " + entry.title)


func test_weapon_tier_table_has_all_tiers() -> void:
	for entry: LexiconEntry in Lexicon.entries(Lexicon.Tab.WEAPONS):
		var table: Array[PackedStringArray] = entry.sections[0].table
		assert_eq(table[0].size(), WeaponData.MAX_TIER + 1, "Spalte je Tier: " + entry.title)
		var weapon: WeaponData = entry.source as WeaponData
		var prices: PackedStringArray = table[table.size() - 1]
		assert_eq(prices[WeaponData.MAX_TIER], str(weapon.get_tier(WeaponData.MAX_TIER).price), "Tier-IV-Preis: " + entry.title)


func test_set_bonus_table_has_column_per_level() -> void:
	for res: Resource in DataRegistry.get_all("sets"):
		var set_bonus: SetBonusData = res as SetBonusData
		var table: Array[PackedStringArray] = Lexicon.set_bonus_table(set_bonus)
		assert_eq(table[0].size(), set_bonus.levels.size() + 1, String(set_bonus.weapon_class))
		assert_gt(table.size(), 1, "mindestens ein Stat: " + String(set_bonus.weapon_class))
		assert_gt(Lexicon.weapons_of_class(set_bonus.weapon_class).size(), 0, "Waffen der Klasse: " + String(set_bonus.weapon_class))


func test_locked_entries_show_condition_and_progress() -> void:
	for entry: LexiconEntry in Lexicon.entries(Lexicon.Tab.CHARACTERS):
		var challenge: ChallengeData = Unlocks.challenge_for(entry.source as CharacterData)
		if challenge == null:
			assert_false(entry.locked, "Startcharakter frei: " + entry.title)
			continue
		assert_true(entry.lock_text.contains(challenge.condition_text()), "Bedingung: " + entry.title)
		if entry.locked and challenge.has_progress():
			assert_true(entry.lock_text.contains(challenge.progress_text(Unlocks.progress(challenge))), "Fortschritt: " + entry.title)
	for entry: LexiconEntry in Lexicon.entries(Lexicon.Tab.ITEMS):
		var challenge: ChallengeData = Lexicon.challenge_for_item(entry.source as ItemData)
		if challenge != null and challenge.condition == ChallengeData.Condition.WIN_WITH_CHARACTER:
			assert_true(entry.lock_text.contains(TextFormat.t(challenge.character.name_key)), "Sieg-Item nennt Charakter: " + entry.title)


func test_enemy_first_waves() -> void:
	for entry: LexiconEntry in Lexicon.entries(Lexicon.Tab.ENEMIES):
		var enemy: EnemyData = entry.source as EnemyData
		var wave: int = Lexicon.first_wave(enemy)
		assert_between(wave, 1, 20, "Auftreten: " + entry.title)
	assert_eq(Lexicon.first_wave(load("res://data/enemies/schattenling.tres")), 1)
	assert_eq(Lexicon.first_wave(load("res://data/enemies/dimmer.tres")), 20)


func test_search_matches_names_and_texts() -> void:
	var weapons: Array[LexiconEntry] = Lexicon.entries(Lexicon.Tab.WEAPONS)
	var hammer: LexiconEntry = null
	for entry: LexiconEntry in weapons:
		if entry.id == &"lampenhammer":
			hammer = entry
	assert_not_null(hammer)
	assert_true(hammer.matches(""))
	assert_true(hammer.matches(hammer.title.to_upper()), "ohne Groß-/Kleinschreibung")
	assert_true(hammer.matches(TextFormat.t("CLASS_HEAVY")), "findet Klassen im Text")
	assert_false(hammer.matches("xyz-gibt-es-nicht"))


func test_screen_filters_and_search() -> void:
	var screen: LexiconScreen = LEXICON_SCENE.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(2)
	screen.show_tab(Lexicon.Tab.WEAPONS)
	screen.set_filter(LexiconScreen.Filter.RANGE, 1)
	for entry: LexiconEntry in screen.filtered_entries(Lexicon.Tab.WEAPONS):
		assert_true(entry.melee, "Filter Nahkampf: " + entry.title)
	screen.set_filter(LexiconScreen.Filter.RANGE, 0)
	var name: String = Lexicon.entries(Lexicon.Tab.ENEMIES)[0].title
	screen.set_search(name)
	await wait_physics_frames(2)
	assert_gt(screen.filtered_entries(Lexicon.Tab.ENEMIES).size(), 0)
	screen.set_search("xyz-gibt-es-nicht")
	await wait_physics_frames(2)
	assert_eq(screen.get_cards().size(), 0, "keine Treffer")


func test_layout_does_not_jump() -> void:
	var screen: LexiconScreen = LEXICON_SCENE.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(3)
	var detail: DetailPanel = screen.get_detail()
	var grid_area: Control = screen.get_grid_area()
	var detail_rect: Rect2 = detail.get_global_rect()
	var grid_rect: Rect2 = grid_area.get_global_rect()
	assert_eq(detail.size, LexiconScreen.DETAIL_SIZE, "Detailpanel hat feste Größe")
	for tab: int in Lexicon.tab_count():
		screen.show_tab(tab)
		await wait_physics_frames(3)
		var cards: Array[EntryCard] = screen.get_cards()
		assert_gt(cards.size(), 0, Lexicon.tab_title(tab))
		var first_position: Vector2 = cards[0].global_position
		for index: int in [0, cards.size() - 1, cards.size() / 2, 1 % cards.size()]:
			cards[index].grab_focus()
			await wait_physics_frames(3)
			assert_eq(detail.get_global_rect(), detail_rect, "Detailpanel bleibt stehen: %s/%d" % [Lexicon.tab_title(tab), index])
			assert_eq(grid_area.get_global_rect(), grid_rect, "Raster bleibt stehen: %s/%d" % [Lexicon.tab_title(tab), index])
			assert_eq(cards[index].size, EntryCard.CARD_SIZE, "Karte hat feste Größe")
		(grid_area as ScrollContainer).scroll_vertical = 0
		await wait_physics_frames(2)
		assert_eq(cards[0].global_position, first_position, "erste Karte unverändert: " + Lexicon.tab_title(tab))
