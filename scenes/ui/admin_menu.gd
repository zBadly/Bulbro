class_name AdminMenu
extends CanvasLayer
## Admin-Menü (F10, nur wenn in den Optionen unter "Erweitert" eingeschaltet): Welle, Spieler, Gegner, Inventar,
## Shop und Meta. Ersetzt das frühere Debug-Menü (F4) und den Arena-Füller (F6).
## Die erste ausgeführte Aktion markiert den Run als Admin-Run (GameState.admin.used): Er zählt dann nicht mehr
## für Freischaltungen, Achievements und Gesamtstatistiken. Nur Öffnen und Umsehen ändert nichts.

signal speed_changed

const SCREEN_MARGIN: float = 16.0
const PANEL_SIZE: Vector2 = Vector2(560, 760)
const TEXT_SIZE: int = 20
const TITLE_SIZE: int = 26
const GAP: int = 10
const MAX_WAVE: int = 99
const MAX_LEVEL: int = 60
const MAX_SPARKS: int = 99999
const MAX_SPAWN_COUNT: int = 50
const SHOP_SLOTS: int = 4
## Streuung beim Spawnen an der Maus, damit Gruppen nicht exakt übereinander liegen.
const MOUSE_SCATTER: float = 40.0

var player: Player
var wave_manager: WaveManager
var shop_screen: ShopScreen

var _characters: Array[CharacterData] = []
var _items: Array[ItemData] = []
var _weapons: Array[WeaponData] = []
var _pets: Array[PetData] = []
var _enemies: Array[EnemyData] = []
var _paused_by_menu: bool = false
var _mouse_world: Vector2 = Vector2.ZERO
## Steuerelemente, die nur während einer Welle funktionieren.
var _wave_only: Array[BaseButton] = []
var _owned_weapons: OptionButton
var _owned_items: OptionButton
var _owned_pets: OptionButton
var _status: Label
var _first_focus: Control
var _toggles: Dictionary[StringName, CheckButton] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_characters = Unlocks.all_characters()
	for res: Resource in DataRegistry.get_all("items"):
		_items.append(res as ItemData)
	_items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return tr(a.name_key) < tr(b.name_key))
	for res: Resource in DataRegistry.get_all("weapons"):
		_weapons.append(res as WeaponData)
	_weapons.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return tr(a.name_key) < tr(b.name_key))
	for res: Resource in DataRegistry.get_all("pets"):
		_pets.append(res as PetData)
	_pets.sort_custom(func(a: PetData, b: PetData) -> bool: return tr(a.name_key) < tr(b.name_key))
	for res: Resource in DataRegistry.get_all("enemies"):
		_enemies.append(res as EnemyData)
	_enemies.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return tr(a.name_key) < tr(b.name_key))
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"admin_menu") and AdminState.is_enabled() and player != null:
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		hide()
		if _paused_by_menu:
			get_tree().paused = false
			_paused_by_menu = false
		return
	_mouse_world = player.get_global_mouse_position()
	_build()
	show()
	_paused_by_menu = not get_tree().paused
	if _paused_by_menu:
		get_tree().paused = true
	_first_focus.call_deferred("grab_focus")


## Führt eine Admin-Aktion aus und markiert den Run. In der Shop-Phase wird der Fortsetzen-Stand
## sofort mit dem Merker neu gespeichert, damit Beenden und Fortsetzen ihn nicht verliert.
func act(action: Callable) -> void:
	GameState.admin.used = true
	action.call()
	if GameState.is_run_active and GameState.phase == GameState.Phase.SHOP:
		SaveManager.save_run(RunSave.capture(player))
	_refresh_state()


# --- Aufbau ---

func _build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_wave_only.clear()
	_toggles.clear()
	var panel: PanelContainer = UiStyle.make_panel()
	panel.custom_minimum_size = PANEL_SIZE
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-PANEL_SIZE.x - SCREEN_MARGIN, SCREEN_MARGIN)
	add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	panel.add_child(box)
	var title: Label = UiStyle.make_label(TITLE_SIZE, UiStyle.SPARK_COLOR)
	title.text = tr("ADMIN_TITLE")
	box.add_child(title)
	_status = UiStyle.make_label(TEXT_SIZE - 4, UiStyle.TIER_COLORS[0])
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_override("font", UiStyle.FONT)
	tabs.add_theme_font_size_override("font_size", TEXT_SIZE)
	box.add_child(tabs)
	_build_run(_tab(tabs, "ADMIN_TAB_RUN"))
	_build_player(_tab(tabs, "ADMIN_TAB_PLAYER"))
	_build_enemies(_tab(tabs, "ADMIN_TAB_ENEMIES"))
	_build_inventory(_tab(tabs, "ADMIN_TAB_INVENTORY"))
	_build_shop(_tab(tabs, "ADMIN_TAB_SHOP"))
	_build_meta(_tab(tabs, "ADMIN_TAB_META"))
	_first_focus = _button(box, tr("ADMIN_CLOSE"), toggle)
	_refresh_state()


func _tab(tabs: TabContainer, key: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = tr(key)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", GAP)
	scroll.add_child(box)
	return box


func _build_run(box: VBoxContainer) -> void:
	var row: HBoxContainer = _row(box, "ADMIN_WAVE")
	var wave: SpinBox = _spin(row, 1, MAX_WAVE, maxi(1, GameState.current_wave))
	_wave_only.append(_button(row, tr("ADMIN_START_WAVE"), func() -> void: act(func() -> void:
		wave_manager.admin_jump_to_wave(roundi(wave.value)))))
	_hint(box, tr("ADMIN_ENDLESS_HINT") % (wave_manager.get_wave_count() + 1))
	_toggle(box, &"time_frozen", "ADMIN_TIME_FROZEN", GameState.admin.time_frozen,
		func(on: bool) -> void: GameState.admin.time_frozen = on)
	_wave_only.append(_button(box, tr("ADMIN_SKIP_WAVE"), func() -> void: act(wave_manager.skip_wave)))
	_wave_only.append(_button(box, tr("ADMIN_REBUILD_TOWERS"), func() -> void: act(func() -> void:
		(get_parent() as Arena).towers.build_wave())))
	var speed_row: HBoxContainer = _row(box, "ADMIN_SPEED")
	var speeds: Array = AdminState.GAME_SPEEDS.map(func(s: float) -> String: return "%sx" % TextFormat.number(s))
	var speed: OptionButton = _option(speed_row, speeds)
	speed.selected = maxi(0, AdminState.GAME_SPEEDS.find(GameState.admin.game_speed))
	speed.item_selected.connect(func(index: int) -> void: act(func() -> void:
		GameState.admin.game_speed = AdminState.GAME_SPEEDS[index]
		speed_changed.emit()))
	_toggle(box, &"hitboxes", "ADMIN_HITBOXES", GameState.admin.show_hitboxes,
		func(on: bool) -> void: GameState.admin.show_hitboxes = on)


func _build_player(box: VBoxContainer) -> void:
	var char_row: HBoxContainer = _row(box, "ADMIN_CHARACTER")
	var character: OptionButton = _option(char_row, _characters.map(func(c: CharacterData) -> String: return tr(c.name_key)))
	character.selected = maxi(0, _characters.find(player.character))
	_button(char_row, tr("ADMIN_SWITCH"), func() -> void: act(func() -> void:
		player.switch_character(_characters[character.selected])))
	var level_row: HBoxContainer = _row(box, "ADMIN_LEVEL")
	var level: SpinBox = _spin(level_row, 0, MAX_LEVEL, GameState.level)
	_button(level_row, tr("ADMIN_SET"), func() -> void: act(func() -> void: player.admin_set_level(roundi(level.value))))
	_button(box, tr("ADMIN_LEVEL_UP"), func() -> void: act(func() -> void: GameState.add_xp(GameState.xp_needed() - GameState.xp)))
	var spark_row: HBoxContainer = _row(box, "ADMIN_SPARKS")
	var sparks: SpinBox = _spin(spark_row, 0, MAX_SPARKS, GameState.sparks)
	_button(spark_row, tr("ADMIN_SET"), func() -> void: act(func() -> void:
		GameState.sparks = roundi(sparks.value)
		Events.sparks_changed.emit(GameState.sparks, GameState.bag)))
	_toggle(box, &"invulnerable", "ADMIN_INVULNERABLE", player.debug_invulnerable,
		func(on: bool) -> void: player.debug_invulnerable = on)
	_toggle(box, &"infinite_hp", "ADMIN_INFINITE_HP", GameState.admin.infinite_hp,
		func(on: bool) -> void: GameState.admin.infinite_hp = on)
	_toggle(box, &"damage", "ADMIN_DAMAGE_BOOST", GameState.admin.damage_factor > 1.0,
		func(on: bool) -> void: GameState.admin.damage_factor = AdminState.DAMAGE_BOOST if on else 1.0)


func _build_enemies(box: VBoxContainer) -> void:
	var enemy: OptionButton = _option(box, _enemies.map(func(e: EnemyData) -> String: return _enemy_label(e)))
	var row: HBoxContainer = _row(box, "ADMIN_COUNT")
	var count: SpinBox = _spin(row, 1, MAX_SPAWN_COUNT, 1)
	var where: OptionButton = _option(row, [tr("ADMIN_AT_MOUSE"), tr("ADMIN_RANDOM")])
	_wave_only.append(_button(box, tr("ADMIN_SPAWN"), func() -> void: act(func() -> void:
		_spawn(_enemies[enemy.selected], roundi(count.value), where.selected == 0))))
	_wave_only.append(_button(box, tr("ADMIN_CLEAR_ENEMIES"), func() -> void: act(wave_manager.clear_enemies)))
	_wave_only.append(_button(box, tr("ADMIN_FILL"), func() -> void: act(func() -> void:
		(get_parent() as Arena).fill_arena())))


func _build_inventory(box: VBoxContainer) -> void:
	var weapon: OptionButton = _option(box, _weapons.map(func(w: WeaponData) -> String: return tr(w.name_key)))
	var tier_row: HBoxContainer = _row(box, "ADMIN_TIER")
	var tier: SpinBox = _spin(tier_row, WeaponData.MIN_TIER, WeaponData.MAX_TIER, WeaponData.MIN_TIER)
	_button(tier_row, tr("ADMIN_GIVE_WEAPON"), func() -> void: act(func() -> void:
		player.weapon_slots.add_or_combine(_weapons[weapon.selected], roundi(tier.value))
		_fill_owned()))
	_owned_weapons = _option(box, [])
	_button(box, tr("ADMIN_REMOVE_WEAPON"), func() -> void: act(_remove_weapon))
	var item: OptionButton = _option(box, _items.map(func(i: ItemData) -> String: return "%s (%s)" % [tr(i.name_key), TextFormat.tier_name(i.tier)]))
	_button(box, tr("ADMIN_GIVE_ITEM"), func() -> void: act(func() -> void:
		GameState.add_item(_items[item.selected])
		player.apply_item(_items[item.selected])
		_fill_owned()))
	_owned_items = _option(box, [])
	_button(box, tr("ADMIN_REMOVE_ITEM"), func() -> void: act(_remove_item))
	var pet: OptionButton = _option(box, _pets.map(func(p: PetData) -> String: return tr(p.name_key)))
	var pet_tier_row: HBoxContainer = _row(box, "ADMIN_TIER")
	var pet_tier: SpinBox = _spin(pet_tier_row, WeaponData.MIN_TIER, WeaponData.MAX_TIER, WeaponData.MIN_TIER)
	_button(pet_tier_row, tr("ADMIN_GIVE_PET"), func() -> void: act(func() -> void:
		player.pet_slots.add_or_combine(_pets[pet.selected], roundi(pet_tier.value))
		_fill_owned()))
	_owned_pets = _option(box, [])
	_button(box, tr("ADMIN_REMOVE_PET"), func() -> void: act(_remove_pet))
	_fill_owned()


func _build_shop(box: VBoxContainer) -> void:
	_toggle(box, &"shop_free", "ADMIN_SHOP_FREE", GameState.admin.shop_free, func(on: bool) -> void:
		GameState.admin.shop_free = on
		shop_screen.refresh())
	_toggle(box, &"free_reroll", "ADMIN_FREE_REROLL", GameState.admin.free_reroll, func(on: bool) -> void:
		GameState.admin.free_reroll = on
		shop_screen.refresh())
	var labels: Array = []
	for item: ItemData in _items:
		labels.append(tr("ADMIN_OFFER_ITEM") % tr(item.name_key))
	for weapon: WeaponData in _weapons:
		labels.append(tr("ADMIN_OFFER_WEAPON") % tr(weapon.name_key))
	for pet: PetData in _pets:
		labels.append(tr("ADMIN_OFFER_PET") % tr(pet.name_key))
	var offer: OptionButton = _option(box, labels)
	var row: HBoxContainer = _row(box, "ADMIN_SHOP_SLOT")
	var slot: SpinBox = _spin(row, 1, SHOP_SLOTS, 1)
	_label(row, "ADMIN_TIER")
	var tier: SpinBox = _spin(row, WeaponData.MIN_TIER, WeaponData.MAX_TIER, WeaponData.MIN_TIER)
	_button(box, tr("ADMIN_PLACE_OFFER"), func() -> void: act(func() -> void:
		_place_offer(offer.selected, roundi(slot.value) - 1, roundi(tier.value))))


func _build_meta(box: VBoxContainer) -> void:
	_button(box, tr("ADMIN_UNLOCK_CHARACTERS"), func() -> void: act(Unlocks.unlock_all_characters))


# --- Aktionen ---

func _spawn(data: EnemyData, count: int, at_mouse: bool) -> void:
	var rng: RandomNumberGenerator = GameState.rng
	for i in count:
		var at: Vector2 = wave_manager.pick_spawn_point()
		if at_mouse:
			at = _mouse_world + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * MOUSE_SCATTER
		wave_manager.spawn_enemy(data, at)


func _remove_weapon() -> void:
	var weapons: Array[Weapon] = player.weapon_slots.get_weapons()
	if _owned_weapons.selected >= 0 and _owned_weapons.selected < weapons.size():
		player.weapon_slots.remove_weapon(weapons[_owned_weapons.selected])
	_fill_owned()


func _remove_pet() -> void:
	var pets: Array[Pet] = player.pet_slots.get_pets()
	if _owned_pets.selected >= 0 and _owned_pets.selected < pets.size():
		player.pet_slots.remove_pet(pets[_owned_pets.selected])
	_fill_owned()


## Items lassen sich nicht einzeln rückgängig machen: Item entfernen und Spieler neu aufbauen.
func _remove_item() -> void:
	var index: int = _owned_items.selected
	if index >= 0 and index < GameState.items.size():
		GameState.items.remove_at(index)
		player.rebuild()
	_fill_owned()


func _place_offer(choice: int, slot: int, tier: int) -> void:
	var ctx: ShopContext = ShopContext.from_run(player)
	if choice < _items.size():
		GameState.shop.place_offer(slot, _items[choice], null, tier, ctx)
	elif choice < _items.size() + _weapons.size():
		GameState.shop.place_offer(slot, null, _weapons[choice - _items.size()], tier, ctx)
	else:
		GameState.shop.place_offer(slot, null, null, tier, ctx, _pets[choice - _items.size() - _weapons.size()])
	shop_screen.refresh()


func _fill_owned() -> void:
	if _owned_weapons == null:
		return
	_owned_weapons.clear()
	for weapon: Weapon in player.weapon_slots.get_weapons():
		_owned_weapons.add_item("%s (%s)" % [tr(weapon.data.name_key), TextFormat.tier_name(weapon.tier)])
	_owned_items.clear()
	for item: ItemData in GameState.items:
		_owned_items.add_item(tr(item.name_key))
	_owned_pets.clear()
	for pet: Pet in player.pet_slots.get_pets():
		_owned_pets.add_item("%s (%s)" % [tr(pet.data.name_key), TextFormat.tier_name(pet.tier)])


func _refresh_state() -> void:
	var in_wave: bool = GameState.is_run_active and GameState.phase == GameState.Phase.WAVE and not player.is_dead
	for button: BaseButton in _wave_only:
		button.disabled = not in_wave
		button.tooltip_text = "" if in_wave else tr("ADMIN_NOT_IN_WAVE")
	if _status != null:
		_status.text = tr("ADMIN_USED_NOTE") if GameState.admin.used else tr("ADMIN_UNUSED_NOTE")


func _enemy_label(data: EnemyData) -> String:
	if data.is_boss:
		return "%s (%s)" % [tr(data.name_key), tr("ADMIN_BOSS")]
	if data.is_elite:
		return "%s (%s)" % [tr(data.name_key), tr("ADMIN_ELITE")]
	return tr(data.name_key)


# --- Bausteine ---

func _row(parent: Control, key: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	parent.add_child(row)
	_label(row, key)
	return row


func _label(parent: Control, key: String) -> void:
	var label: Label = UiStyle.make_label(TEXT_SIZE)
	label.text = tr(key)
	parent.add_child(label)


func _hint(parent: Control, text: String) -> void:
	var label: Label = UiStyle.make_label(TEXT_SIZE - 4, UiStyle.TIER_COLORS[0])
	label.text = text
	parent.add_child(label)


func _option(parent: Control, labels: Array) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.add_theme_font_override("font", UiStyle.FONT)
	option.add_theme_font_size_override("font_size", TEXT_SIZE)
	option.fit_to_longest_item = false
	for label: String in labels:
		option.add_item(label)
	parent.add_child(option)
	return option


func _spin(parent: Control, min_value: int, max_value: int, value: int) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = clampi(value, min_value, max_value)
	parent.add_child(spin)
	return spin


func _toggle(parent: Control, id: StringName, key: String, pressed: bool, on_toggle: Callable) -> CheckButton:
	var toggle_button: CheckButton = CheckButton.new()
	toggle_button.text = tr(key)
	toggle_button.add_theme_font_override("font", UiStyle.FONT)
	toggle_button.add_theme_font_size_override("font_size", TEXT_SIZE)
	toggle_button.button_pressed = pressed
	toggle_button.toggled.connect(func(on: bool) -> void: act(on_toggle.bind(on)))
	parent.add_child(toggle_button)
	_toggles[id] = toggle_button
	return toggle_button


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = UiStyle.make_button(text, TEXT_SIZE)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
