class_name StatsScreen
extends Control
## Statistik-Bildschirm (Hauptmenü, Phase 15, Paket 9): Reiter Allgemein, Charaktere, Waffen/Items, Gegner,
## Run-Historie (anklickbar mit Details) und Achievements. Werte liefert MetaStats aus dem Spielstand.
## Reiter: Maus, Q/E bzw. LB/RB; rechter Stick bzw. Bild auf/ab scrollt; Esc/B zurück ins Hauptmenü.

enum Tab { GENERAL, CHARACTERS, GEAR, ENEMIES, HISTORY, ACHIEVEMENTS }

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const FLOOR_TEXTURE: Texture2D = preload("res://art/world/floor_tile.svg")
const TAB_KEYS: PackedStringArray = [
	"META_TAB_GENERAL", "META_TAB_CHARACTERS", "META_TAB_GEAR", "META_TAB_ENEMIES", "META_TAB_HISTORY", "META_TAB_ACHIEVEMENTS",
]
const DIM_COLOR: Color = Color("#0B0B12B3")
const HINT_COLOR: Color = Color("#C9C3D6")
const HEADING_COLOR: Color = Color("#FFD43B")
const TITLE_SIZE: int = 52
const TEXT_SIZE: int = 22
const HEADING_SIZE: int = 26
const HINT_SIZE: int = 18
const GAP: int = 16
const TAB_WIDTH: float = 250.0
const ROW_HEIGHT: float = 52.0
## Feste Seitengröße (Basisauflösung 1920 x 1080; skaliert über stretch mode canvas_items).
const PAGE_SIZE: Vector2 = Vector2(1824, 790)
const HISTORY_LIST_WIDTH: float = 980.0
const STICK_DEADZONE: float = 0.25
const SCROLL_SPEED: float = 900.0
const PAGE_SCROLL_SHARE: float = 0.5

var _tab: int = Tab.GENERAL
var _tab_buttons: Array[Button] = []
var _page: Control
## Scrollbereiche der aktuellen Seite (Stick und Bild auf/ab scrollen den ersten).
var _scrolls: Array[ScrollContainer] = []
var _history_detail: VBoxContainer
var _history_buttons: Array[Button] = []
var _achievements: AchievementList


func _ready() -> void:
	get_tree().paused = false
	_build()
	show_tab(Tab.GENERAL)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tab_prev"):
		show_tab(posmod(_tab - 1, TAB_KEYS.size()))
	elif event.is_action_pressed(&"tab_next"):
		show_tab(posmod(_tab + 1, TAB_KEYS.size()))
	elif event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	elif event.is_action_pressed(&"ui_page_up"):
		_scroll_by(-PAGE_SIZE.y * PAGE_SCROLL_SHARE)
	elif event.is_action_pressed(&"ui_page_down"):
		_scroll_by(PAGE_SIZE.y * PAGE_SCROLL_SHARE)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var axis: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(axis) > STICK_DEADZONE:
		_scroll_by(axis * SCROLL_SPEED * delta)


func _scroll_by(pixels: float) -> void:
	for scroll: ScrollContainer in _scrolls:
		if is_instance_valid(scroll):
			scroll.scroll_vertical += roundi(pixels)


func _build() -> void:
	var floor_rect: TextureRect = TextureRect.new()
	floor_rect.texture = FLOOR_TEXTURE
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	floor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(floor_rect)
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", GAP)
	center.add_child(content)

	var top: HBoxContainer = HBoxContainer.new()
	content.add_child(top)
	var title: Label = UiStyle.make_label(TITLE_SIZE)
	title.text = tr("META_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var counter: Label = UiStyle.make_label(TEXT_SIZE, UiStyle.SPARK_COLOR)
	counter.text = tr("ACH_COUNTER") % [Unlocks.completed_achievement_count(), Unlocks.all_achievements().size()]
	counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(counter)

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", GAP / 2)
	content.add_child(tabs)
	var group: ButtonGroup = ButtonGroup.new()
	for tab: int in TAB_KEYS.size():
		var button: Button = UiStyle.make_button(tr(TAB_KEYS[tab]), TEXT_SIZE)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(TAB_WIDTH, ROW_HEIGHT)
		var pressed: StyleBoxFlat = button.get_theme_stylebox("pressed").duplicate()
		pressed.bg_color = UiStyle.BUTTON_FOCUS_COLOR
		pressed.border_color = UiStyle.SPARK_COLOR
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("hover_pressed", pressed)
		button.pressed.connect(show_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons.append(button)
	var hint: Label = UiStyle.make_label(HINT_SIZE, HINT_COLOR)
	hint.text = tr("LEX_TAB_HINT")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tabs.add_child(hint)

	_page = Control.new()
	_page.custom_minimum_size = PAGE_SIZE
	content.add_child(_page)

	var back: Button = UiStyle.make_button(tr("BACK"), TEXT_SIZE)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	content.add_child(back)


# --- Reiter ---

func show_tab(tab: int) -> void:
	_tab = tab
	for index: int in _tab_buttons.size():
		_tab_buttons[index].set_pressed_no_signal(index == tab)
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_scrolls.clear()
	_history_buttons.clear()
	_achievements = null
	var page: Control
	match tab:
		Tab.GENERAL:
			page = _columns([[tr("META_HEADING_GENERAL"), MetaStats.general_rows()], [tr("META_HEADING_RECORDS"), MetaStats.record_rows()]])
		Tab.CHARACTERS:
			page = _columns([[tr("META_HEADING_CHARACTERS"), MetaStats.character_rows()]])
		Tab.GEAR:
			page = _columns([[tr("META_HEADING_WEAPONS"), MetaStats.weapon_rows()], [tr("META_HEADING_ITEMS"), MetaStats.item_rows()]])
		Tab.ENEMIES:
			page = _columns([[tr("META_HEADING_ENEMIES"), MetaStats.enemy_rows()]])
		Tab.HISTORY:
			page = _history_page()
		Tab.ACHIEVEMENTS:
			_achievements = AchievementList.new()
			_scrolls.append(_achievements.get_scroll())
			page = _achievements
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.add_child(page)
	_focus_first.call_deferred()


func current_tab() -> int:
	return _tab


func get_achievement_list() -> AchievementList:
	return _achievements


func history_button_count() -> int:
	return _history_buttons.size()


func _focus_first() -> void:
	if not _history_buttons.is_empty():
		_history_buttons[0].grab_focus()
	elif _achievements != null:
		_achievements.get_filter().grab_focus()


## Spalten nebeneinander, je Überschrift und Tabelle in einem eigenen Scrollbereich.
func _columns(columns: Array) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	for column: Array in columns:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(scroll)
		_scrolls.append(scroll)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", GAP / 2)
		scroll.add_child(box)
		box.add_child(_heading(column[0]))
		var table: StatTable = StatTable.new()
		table.set_rows(column[1])
		box.add_child(table)
	return row


func _heading(text: String) -> Label:
	var label: Label = UiStyle.make_label(HEADING_SIZE, HEADING_COLOR)
	label.text = text
	return label


# --- Run-Historie ---

func _history_page() -> Control:
	var history: Array[Dictionary] = SaveManager.get_run_history()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = Vector2(HISTORY_LIST_WIDTH, 0.0)
	list_scroll.follow_focus = true
	row.add_child(list_scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", GAP / 2)
	list_scroll.add_child(list)
	var detail_scroll: ScrollContainer = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail_scroll)
	_scrolls.append(detail_scroll)
	_history_detail = VBoxContainer.new()
	_history_detail.add_theme_constant_override("separation", GAP / 2)
	detail_scroll.add_child(_history_detail)
	if history.is_empty():
		var empty: Label = UiStyle.make_label(TEXT_SIZE, HINT_COLOR)
		empty.text = tr("META_HISTORY_EMPTY")
		list.add_child(empty)
		return row
	list.add_child(_heading(tr("META_HISTORY_HEADING") % history.size()))
	for entry: Dictionary in history:
		var button: Button = UiStyle.make_button(MetaStats.history_title(entry), HINT_SIZE + 2)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_history_entry.bind(entry))
		button.focus_entered.connect(show_history_entry.bind(entry))
		list.add_child(button)
		_history_buttons.append(button)
	show_history_entry(history[0])
	return row


func show_history_entry(entry: Dictionary) -> void:
	for child: Node in _history_detail.get_children():
		_history_detail.remove_child(child)
		child.queue_free()
	_history_detail.add_child(_heading(tr("META_HISTORY_DETAIL")))
	var table: StatTable = StatTable.new()
	table.set_rows(MetaStats.history_rows(entry))
	_history_detail.add_child(table)
	_history_detail.add_child(_heading(tr("META_HISTORY_SOURCES")))
	var sources: StatTable = StatTable.new()
	sources.set_rows(MetaStats.history_source_rows(entry))
	_history_detail.add_child(sources)
