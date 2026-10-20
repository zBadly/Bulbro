class_name DebugMenu
extends CanvasLayer
## Debug-Menü (F4, nur Debug-Builds): Items und Waffen geben, zu einer Welle springen, unverwundbar, Funken, Level.
## Texte sind Entwicklerwerkzeug und laufen trotzdem über die Übersetzungstabelle.

const SCREEN_MARGIN: float = 16.0
const PANEL_WIDTH: float = 420.0
const TEXT_SIZE: int = 20
const GAP: int = 10
const DEBUG_SPARKS: int = 100

var player: Player
var wave_manager: WaveManager

var _items: Array[ItemData] = []
var _weapons: Array[WeaponData] = []
var _item_select: OptionButton
var _weapon_select: OptionButton
var _tier_select: SpinBox
var _wave_select: SpinBox
var _jump_button: Button
var _invulnerable: CheckButton
var _paused_by_menu: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for res: Resource in DataRegistry.get_all("items"):
		_items.append(res as ItemData)
	_items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return tr(a.name_key) < tr(b.name_key))
	for res: Resource in DataRegistry.get_all("weapons"):
		_weapons.append(res as WeaponData)
	_weapons.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return tr(a.name_key) < tr(b.name_key))
	_build()
	hide()


func _build() -> void:
	var panel: PanelContainer = UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-PANEL_WIDTH - SCREEN_MARGIN, SCREEN_MARGIN)
	add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	panel.add_child(box)
	var title: Label = UiStyle.make_label(TEXT_SIZE + 6)
	title.text = tr("DEBUG_MENU_TITLE")
	box.add_child(title)

	_item_select = _option(box, _items.map(func(i: ItemData) -> String: return "%s (%s)" % [tr(i.name_key), TextFormat.tier_name(i.tier)]))
	_button(box, tr("DEBUG_GIVE_ITEM"), _give_item)

	_weapon_select = _option(box, _weapons.map(func(w: WeaponData) -> String: return tr(w.name_key)))
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	_tier_select = _spin(row, WeaponData.MIN_TIER, WeaponData.MAX_TIER)
	_button(row, tr("DEBUG_GIVE_WEAPON"), _give_weapon)

	var wave_row: HBoxContainer = HBoxContainer.new()
	box.add_child(wave_row)
	_wave_select = _spin(wave_row, 1, maxi(1, wave_manager.get_wave_count() if wave_manager != null else 20))
	_jump_button = _button(wave_row, tr("DEBUG_JUMP_WAVE"), _jump_wave)

	_invulnerable = CheckButton.new()
	_invulnerable.text = tr("DEBUG_INVULNERABLE")
	_invulnerable.add_theme_font_override("font", UiStyle.FONT)
	_invulnerable.add_theme_font_size_override("font_size", TEXT_SIZE)
	_invulnerable.toggled.connect(func(on: bool) -> void: player.debug_invulnerable = on)
	box.add_child(_invulnerable)

	_button(box, tr("DEBUG_ADD_SPARKS") % DEBUG_SPARKS, func() -> void: GameState.add_sparks(DEBUG_SPARKS))
	_button(box, tr("DEBUG_LEVEL_UP"), func() -> void: GameState.add_xp(GameState.xp_needed() - GameState.xp))
	_button(box, tr("DEBUG_CLOSE"), _toggle)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_menu"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	visible = not visible
	var in_wave: bool = GameState.phase == GameState.Phase.WAVE
	if visible:
		_jump_button.disabled = not in_wave
		_invulnerable.button_pressed = player.debug_invulnerable
		_paused_by_menu = in_wave and not get_tree().paused
		if _paused_by_menu:
			get_tree().paused = true
		_item_select.grab_focus()
	elif _paused_by_menu:
		get_tree().paused = false
		_paused_by_menu = false


func _give_item() -> void:
	var item: ItemData = _items[_item_select.selected]
	GameState.add_item(item)
	player.apply_item(item)


func _give_weapon() -> void:
	player.weapon_slots.add_or_combine(_weapons[_weapon_select.selected], roundi(_tier_select.value))


func _jump_wave() -> void:
	wave_manager.jump_to_wave(roundi(_wave_select.value))
	_toggle()


func _option(parent: Control, labels: Array) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.add_theme_font_override("font", UiStyle.FONT)
	option.add_theme_font_size_override("font_size", TEXT_SIZE)
	for label: String in labels:
		option.add_item(label)
	parent.add_child(option)
	return option


func _spin(parent: Control, min_value: int, max_value: int) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = min_value
	parent.add_child(spin)
	return spin


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = UiStyle.make_button(text, TEXT_SIZE)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
