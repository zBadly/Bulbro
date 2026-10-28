extends GutTest
## Phase 15, Paket 4: Tooltip-Platzierung am Bildschirmrand, Inhalte (Waffe, Set-Boni, Item, Stat) und Stat-Panel.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const GLASSCHERBE: WeaponData = preload("res://data/weapons/glasscherbe.tres")
const BLADE_SET: SetBonusData = preload("res://data/sets/blade.tres")
## Größter realistischer Tooltip (Waffe mit zwei Klassen und Set-Bonus-Listen).
const BIG_TIP: Vector2 = Vector2(484, 640)
const SCREENS: Array[Vector2] = [Vector2(1920, 1080), Vector2(1280, 720)]

var _player: Player


func before_each() -> void:
	GameState.start_run(44)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


# --- Platzierung ---

func _assert_inside(tip: Rect2, area: Rect2, label: String) -> void:
	assert_true(area.grow(-GameTooltip.MARGIN + 0.01).encloses(tip), "%s: %s liegt nicht in %s" % [label, tip, area])


func test_place_prefers_right_side() -> void:
	var anchor: Rect2 = Rect2(100, 100, 56, 56)
	var pos: Vector2 = GameTooltip.place(anchor, Vector2(300, 200), Rect2(Vector2.ZERO, SCREENS[0]))
	assert_eq(pos, Vector2(anchor.end.x + GameTooltip.GAP, anchor.position.y))


func test_place_flips_left_at_right_edge() -> void:
	var anchor: Rect2 = Rect2(1800, 100, 56, 56)
	var pos: Vector2 = GameTooltip.place(anchor, Vector2(300, 200), Rect2(Vector2.ZERO, SCREENS[0]))
	assert_eq(pos.x, anchor.position.x - GameTooltip.GAP - 300.0)


func test_place_never_leaves_the_screen() -> void:
	for screen: Vector2 in SCREENS:
		var area: Rect2 = Rect2(Vector2.ZERO, screen)
		var icon: Vector2 = Vector2(56, 56)
		# Ecken, Ränder, Mitte, letzte Reihe ganz rechts
		var anchors: Array[Rect2] = [
			Rect2(Vector2.ZERO, icon), Rect2(Vector2(screen.x - icon.x, 0), icon),
			Rect2(Vector2(0, screen.y - icon.y), icon), Rect2(screen - icon, icon),
			Rect2(screen * 0.5, icon), Rect2(Vector2(screen.x - icon.x - 4, screen.y - icon.y - 4), icon),
			Rect2(Vector2(screen.x * 0.5 - 450, screen.y - 70), Vector2(900, 60)),
		]
		for anchor: Rect2 in anchors:
			for tip_size: Vector2 in [Vector2(200, 80), BIG_TIP]:
				var pos: Vector2 = GameTooltip.place(anchor, tip_size, area)
				_assert_inside(Rect2(pos, tip_size), area, "%s Anker %s" % [screen, anchor])


func test_place_does_not_cover_anchor_when_room_exists() -> void:
	var area: Rect2 = Rect2(Vector2.ZERO, SCREENS[1])
	var anchor: Rect2 = Rect2(SCREENS[1] - Vector2(56, 56), Vector2(56, 56))
	var pos: Vector2 = GameTooltip.place(anchor, BIG_TIP, area)
	assert_false(Rect2(pos, BIG_TIP).intersects(anchor), "Tooltip links vom Icon in der Ecke rechts unten")


func test_tooltip_follows_focus_and_stays_on_screen() -> void:
	var button: Button = Button.new()
	button.text = "x"
	button.custom_minimum_size = Vector2(56, 56)
	add_child_autofree(button)
	var area: Rect2 = button.get_viewport_rect()
	button.position = area.end - Vector2(60, 60)
	GameTooltip.attach(button, func() -> String: return "Zeile\n".repeat(20))
	button.focus_entered.emit()
	await wait_process_frames(2)
	assert_ne(GameTooltip.current_text(), "")
	_assert_inside(GameTooltip.current_rect(), area, "echter Tooltip")
	button.focus_exited.emit()
	assert_eq(GameTooltip.current_text(), "")


func test_tooltip_hides_when_owner_is_freed() -> void:
	var button: Button = Button.new()
	add_child(button)
	GameTooltip.attach(button, func() -> String: return "Text")
	button.mouse_entered.emit()
	assert_ne(GameTooltip.current_text(), "")
	button.free()
	assert_eq(GameTooltip.current_text(), "")


# --- Inhalte ---

func _custom_weapon() -> Weapon:
	var data: WeaponData = GLASSCHERBE.duplicate(true)
	var tier: WeaponTierStats = data.get_tier(1)
	tier.base_damage = 12.0
	tier.scalings = {Stats.MELEE_DMG: 0.5}
	var weapon: Weapon = _player.weapon_slots.add_weapon(data, 1)
	return weapon


func test_weapon_damage_breakdown() -> void:
	var weapon: Weapon = _custom_weapon()
	_player.stats.add_base_value(Stats.MELEE_DMG, 12.0)
	var expected: String = TextFormat.t("TIP_DAMAGE") % ("18 = 12 + " + TextFormat.t("TIP_DAMAGE_SCALING") % [50, "12", TextFormat.t("STAT_MELEE_DMG")])
	assert_eq(TooltipText.weapon_damage_line(weapon), expected)


func test_weapon_damage_breakdown_with_damage_pct() -> void:
	var weapon: Weapon = _custom_weapon()
	_player.stats.add_base_value(Stats.MELEE_DMG, 12.0)
	_player.stats.add_base_value(Stats.DAMAGE_PCT, 50.0)
	var line: String = TooltipText.weapon_damage_line(weapon)
	assert_string_contains(line, "27 = 12 + ")
	assert_string_contains(line, TextFormat.t("TIP_DAMAGE_PCT") % "+50")


func test_weapon_tooltip_lists_classes_set_bonus_and_run_values() -> void:
	var weapon: Weapon = _player.weapon_slots.add_weapon(GLASSCHERBE, 2)
	GameState.run_stats.record_kill(DamageSource.weapon(GLASSCHERBE.id))
	GameState.run_stats.record_damage(DamageSource.weapon(GLASSCHERBE.id), 77)
	var text: String = TooltipText.weapon(weapon)
	assert_string_contains(text, TextFormat.t(GLASSCHERBE.name_key))
	assert_string_contains(text, TextFormat.weapon_classes_text(GLASSCHERBE))
	assert_string_contains(text, TextFormat.t("TIP_RUN") % [1, 77])
	for weapon_class: StringName in GLASSCHERBE.classes:
		if TooltipText.set_bonus_for(weapon_class) != null:
			assert_string_contains(text, "1/%d %s" % [TooltipText.max_level(TooltipText.set_bonus_for(weapon_class)), TextFormat.t(WeaponClasses.label_key(weapon_class))])


func test_set_bonus_text_highlights_current_level() -> void:
	var text: String = TooltipText.set_bonus_text(BLADE_SET, 3)
	var top: int = TooltipText.max_level(BLADE_SET)
	assert_eq(top, 6)
	assert_string_contains(text, "3/6 %s" % TextFormat.t("CLASS_BLADE"))
	assert_string_contains(text, TextFormat.t("TIP_SET_NEXT") % 4)
	assert_string_contains(text, "[color=%s]» %s" % [TooltipText.ACTIVE_COLOR, TextFormat.t("TIP_SET_LEVEL") % [3, ""]])
	for level: int in range(2, top + 1):
		assert_string_contains(text, TextFormat.t("TIP_SET_LEVEL") % [level, ""])


func test_set_bonus_text_below_and_at_max() -> void:
	assert_string_contains(TooltipText.set_bonus_text(BLADE_SET, 1), TextFormat.t("TIP_SET_NONE"))
	assert_string_contains(TooltipText.set_bonus_text(BLADE_SET, 1), TextFormat.t("TIP_SET_NEXT") % 2)
	assert_string_contains(TooltipText.set_bonus_text(BLADE_SET, 6), TextFormat.t("TIP_SET_MAX"))


func test_set_bonus_text_applies_character_multiplier() -> void:
	var normal: Array[StatModifier] = BLADE_SET.modifiers_for(2)
	var doubled: String = TooltipText.set_bonus_text(BLADE_SET, 2, 2.0)
	assert_string_contains(doubled, TextFormat.signed_number(normal[0].value * 2.0))


func test_item_tooltip_shows_run_values_only_when_used() -> void:
	var item: ItemData = DataRegistry.get_all("items")[0] as ItemData
	assert_false(TooltipText.item(item, 1).contains(TextFormat.t("TIP_RUN") % [0, 0]))
	GameState.run_stats.record_damage(DamageSource.item(item.id), 40)
	assert_string_contains(TooltipText.item(item, 2), TextFormat.t("TIP_RUN_ALL") % [2, 0, 40])
	assert_string_contains(TooltipText.item(item, 2), " x2")


# --- Stat-Panel ---

func _panel() -> StatPanel:
	var panel: StatPanel = StatPanel.new()
	add_child_autofree(panel)
	panel.setup(_player.stats)
	return panel


func test_stat_colors_and_caps() -> void:
	var panel: StatPanel = _panel()
	var cap: float = StatPanel.cap_of(Stats.DODGE)
	assert_eq(cap, _player.config.dodge_cap)
	_player.stats.add_base_value(Stats.DODGE, cap - 15.0)
	_player.stats.add_base_value(Stats.ARMOR, -3.0)
	_player.stats.add_base_value(Stats.ITEM_PRICE_PCT, -10.0)
	var dodge: String = panel.line(Stats.DODGE)
	assert_string_contains(dodge, TextFormat.GOOD_COLOR)
	assert_string_contains(dodge, TextFormat.t("STAT_CAP") % (TextFormat.number(cap) + " %"))
	assert_string_contains(panel.line(Stats.ARMOR), TextFormat.BAD_COLOR)
	assert_string_contains(panel.line(Stats.ITEM_PRICE_PCT), TextFormat.GOOD_COLOR, "weniger Preis ist gut")
	assert_false(panel.line(Stats.LUCK).contains("[color"), "0 ist neutral")
	_player.stats.add_base_value(Stats.DODGE, 30.0)
	assert_string_contains(panel.line(Stats.DODGE), TooltipText.CAP_COLOR, "Obergrenze erreicht")


func test_uncapped_stats_show_no_cap() -> void:
	var panel: StatPanel = _panel()
	assert_eq(StatPanel.cap_of(Stats.ARMOR), INF)
	assert_false(panel.line(Stats.ARMOR).contains(TextFormat.t("STAT_CAP") % ""))


func test_stat_tooltip_uses_lexicon_texts() -> void:
	var capped: String = TooltipText.stat(Stats.DODGE, StatPanel.cap_of(Stats.DODGE))
	assert_string_contains(capped, Lexicon.stat_text(Stats.DODGE, Lexicon.STAT_INFO_PART))
	assert_string_contains(capped, Lexicon.stat_text(Stats.DODGE, Lexicon.STAT_LIMIT_PART))
	var plain: String = TooltipText.stat(Stats.ARMOR, INF)
	assert_string_contains(plain, Lexicon.stat_text(Stats.ARMOR, Lexicon.STAT_INFO_PART))
	assert_false(plain.contains(TextFormat.t("LEX_STAT_LIMIT")))


func test_every_capped_stat_has_a_limit_text() -> void:
	for stat: StringName in Stats.all():
		if StatPanel.cap_of(stat) != INF:
			assert_ne(Lexicon.stat_text(stat, Lexicon.STAT_LIMIT_PART), "STAT_LIMIT_" + String(stat).to_upper())


func test_secondary_rows_hidden_when_zero() -> void:
	var panel: StatPanel = _panel()
	assert_false(panel.get_row(Stats.BOUNCES).visible)
	_player.stats.add_base_value(Stats.BOUNCES, 1.0)
	panel.refresh()
	assert_true(panel.get_row(Stats.BOUNCES).visible)
	assert_true(panel.get_row(Stats.ARMOR).visible, "Primär-Stats immer sichtbar")


func test_build_overview_has_icon_per_weapon_and_item_stack() -> void:
	_player.weapon_slots.add_weapon(GLASSCHERBE, 1)
	_player.weapon_slots.add_weapon(GLASSCHERBE, 3)
	var item: ItemData = DataRegistry.get_all("items")[0] as ItemData
	GameState.add_item(item)
	GameState.add_item(item)
	var overview: BuildOverview = BuildOverview.new(_player)
	add_child_autofree(overview)
	assert_eq(overview.icons.size(), 3)
	for icon: BuildIcon in overview.icons:
		assert_eq(icon.focus_mode, Control.FOCUS_ALL, "per Gamepad erreichbar")
