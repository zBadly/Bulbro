class_name LexiconScreen
extends Control
## Lexikon (Hauptmenü): Reiter für Charaktere, Waffen, Items, Gegner, Waffenklassen und Spielmechaniken.
## Feste Bereiche wie in der Charakterauswahl: Raster links, Detailpanel rechts; nichts springt beim Auswählen.
## Reiter: Maus, Q/E bzw. LB/RB. Das Suchfeld filtert alle Reiter, die Trefferzahl steht im Reitertitel.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const FLOOR_TEXTURE: Texture2D = preload("res://art/world/floor_tile.svg")
const DIM_COLOR: Color = Color("#0B0B12B3")
const HINT_COLOR: Color = Color("#C9C3D6")
const MARGIN: int = 40
const GAP: int = 16
const TITLE_SIZE: int = 52
const TEXT_SIZE: int = 22
const HINT_SIZE: int = 18
const SEARCH_WIDTH: float = 560.0
const TAB_WIDTH: float = 236.0
const ROW_HEIGHT: float = 52.0
const FILTER_WIDTH: float = 260.0
## Feste Bereiche (Basisauflösung 1920 x 1080; skaliert über stretch mode canvas_items).
const GRID_COLUMNS: int = 6
const GRID_GAP: int = 12
const GRID_SIZE: Vector2 = Vector2(1000, 712)
const DETAIL_SIZE: Vector2 = Vector2(808, 712)
## Rechter Stick scrollt das Detailpanel ab dieser Auslenkung.
const STICK_DEADZONE: float = 0.25

enum Filter { CLASS, RANGE, TIER, TAG, SORT, KIND }

var _entries: Array[Array] = []
var _tab: int = Lexicon.Tab.CHARACTERS
## Gewählter Index je Filter (0 = Alle).
var _filters: Dictionary[int, int] = {}
var _selected: Dictionary[int, StringName] = {}
var _tab_buttons: Array[Button] = []
var _search: LineEdit
var _filter_row: HBoxContainer
var _grid_scroll: ScrollContainer
var _grid: GridContainer
var _detail: DetailPanel
var _visible_entries: Array[LexiconEntry] = []
var _class_options: Array[StringName] = []
var _tier_options: Array[int] = []
var _tag_options: Array[StringName] = []


func _ready() -> void:
	get_tree().paused = false
	for tab: int in Lexicon.tab_count():
		var list: Array[LexiconEntry] = Lexicon.entries(tab)
		_entries.append(list)
	_collect_filter_options()
	_build()
	_show_tab(Lexicon.Tab.CHARACTERS)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tab_prev"):
		_show_tab(posmod(_tab - 1, Lexicon.tab_count()))
	elif event.is_action_pressed(&"tab_next"):
		_show_tab(posmod(_tab + 1, Lexicon.tab_count()))
	elif event.is_action_pressed(&"ui_cancel"):
		if _search.has_focus():
			_focus_grid()
		else:
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	elif event.is_action_pressed(&"ui_page_up"):
		_detail.scroll_by(-_detail.size.y * 0.5)
	elif event.is_action_pressed(&"ui_page_down"):
		_detail.scroll_by(_detail.size.y * 0.5)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var axis: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(axis) > STICK_DEADZONE:
		_detail.scroll_by(axis * DetailPanel.SCROLL_SPEED * delta)


# --- Aufbau ---

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

	# Kopf: Titel und Suche
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", GAP)
	content.add_child(top)
	var title: Label = UiStyle.make_label(TITLE_SIZE)
	title.text = tr("LEX_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = tr("LEX_SEARCH")
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(SEARCH_WIDTH, ROW_HEIGHT)
	_search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search.add_theme_font_override("font", UiStyle.FONT)
	_search.add_theme_font_size_override("font_size", TEXT_SIZE)
	_search.add_theme_stylebox_override("normal", _field_style(false))
	_search.add_theme_stylebox_override("focus", _field_style(true))
	_search.text_changed.connect(_on_search_changed)
	top.add_child(_search)

	# Reiter
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", GAP / 2)
	content.add_child(tabs)
	var group: ButtonGroup = ButtonGroup.new()
	for tab: int in Lexicon.tab_count():
		var button: Button = UiStyle.make_button("", TEXT_SIZE)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.custom_minimum_size = Vector2(TAB_WIDTH, ROW_HEIGHT)
		var pressed: StyleBoxFlat = button.get_theme_stylebox("pressed").duplicate()
		pressed.bg_color = UiStyle.BUTTON_FOCUS_COLOR
		pressed.border_color = UiStyle.SPARK_COLOR
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("hover_pressed", pressed)
		button.pressed.connect(_show_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons.append(button)
	var hint: Label = UiStyle.make_label(HINT_SIZE, HINT_COLOR)
	hint.text = tr("LEX_TAB_HINT")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tabs.add_child(hint)

	# Filterzeile: fester Rahmen, damit Reiter mit und ohne Filter gleich hoch sind (kein Container misst den Inhalt)
	var filter_area: Control = Control.new()
	filter_area.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	content.add_child(filter_area)
	_filter_row = HBoxContainer.new()
	_filter_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_filter_row.add_theme_constant_override("separation", GAP)
	filter_area.add_child(_filter_row)

	# Raster und Detailpanel
	var main: HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override("separation", GAP)
	content.add_child(main)
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.custom_minimum_size = GRID_SIZE
	_grid_scroll.follow_focus = true
	main.add_child(_grid_scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	_grid_scroll.add_child(_grid)
	_detail = DetailPanel.new()
	_detail.custom_minimum_size = DETAIL_SIZE
	main.add_child(_detail)

	var bottom: HBoxContainer = HBoxContainer.new()
	content.add_child(bottom)
	var back: Button = UiStyle.make_button(tr("BACK"), TEXT_SIZE)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	bottom.add_child(back)


func _field_style(focused: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = UiStyle.panel_style()
	style.bg_color = UiStyle.BAR_BG_COLOR
	style.border_color = UiStyle.BUTTON_FOCUS_COLOR if focused else UiStyle.OUTLINE_COLOR
	style.set_border_width_all(UiStyle.BORDER_WIDTH)
	return style


## Filterwerte stammen aus den Einträgen selbst (neue Klassen, Tiers oder Tags erscheinen automatisch).
func _collect_filter_options() -> void:
	for entry: LexiconEntry in _entries[Lexicon.Tab.WEAPONS]:
		for weapon_class: StringName in entry.classes:
			if weapon_class not in _class_options:
				_class_options.append(weapon_class)
	_class_options.sort_custom(func(a: StringName, b: StringName) -> bool:
		return tr(WeaponClasses.label_key(a)).naturalnocasecmp_to(tr(WeaponClasses.label_key(b))) < 0)
	for entry: LexiconEntry in _entries[Lexicon.Tab.ITEMS]:
		if entry.tier not in _tier_options:
			_tier_options.append(entry.tier)
		for tag: StringName in entry.tags:
			if tag not in _tag_options:
				_tag_options.append(tag)
	_tier_options.sort()
	_tag_options.sort_custom(func(a: StringName, b: StringName) -> bool:
		return tr(Lexicon.tag_key(a)).naturalnocasecmp_to(tr(Lexicon.tag_key(b))) < 0)


# --- Reiter und Filter ---

func _show_tab(tab: int) -> void:
	_set_tab(tab)
	_refresh_grid()
	_focus_grid()


func _set_tab(tab: int) -> void:
	_tab = tab
	for index: int in _tab_buttons.size():
		_tab_buttons[index].set_pressed_no_signal(index == tab)
	_build_filters()


func _build_filters() -> void:
	for child: Node in _filter_row.get_children():
		_filter_row.remove_child(child)
		child.queue_free()
	match _tab:
		Lexicon.Tab.WEAPONS:
			var classes: PackedStringArray = []
			for weapon_class: StringName in _class_options:
				classes.append(tr(WeaponClasses.label_key(weapon_class)))
			_add_filter(Filter.CLASS, tr("LEX_FILTER_CLASS"), classes, true)
			_add_filter(Filter.RANGE, tr("LEX_FILTER_RANGE"), PackedStringArray([tr("LEX_MELEE"), tr("LEX_RANGED")]), true)
		Lexicon.Tab.ITEMS:
			var tiers: PackedStringArray = []
			for tier: int in _tier_options:
				tiers.append(TextFormat.tier_name(tier))
			var tags: PackedStringArray = []
			for tag: StringName in _tag_options:
				tags.append(tr(Lexicon.tag_key(tag)))
			_add_filter(Filter.TIER, tr("LEX_FILTER_TIER"), tiers, true)
			_add_filter(Filter.TAG, tr("LEX_FILTER_TAG"), tags, true)
			_add_filter(Filter.SORT, tr("LEX_SORT"), PackedStringArray([tr("LEX_SORT_TIER"), tr("LEX_SORT_NAME")]), false)
		Lexicon.Tab.ENEMIES:
			var kinds: PackedStringArray = []
			for key: String in Lexicon.ENEMY_KIND_KEYS:
				kinds.append(tr(key))
			_add_filter(Filter.KIND, tr("LEX_FILTER_KIND"), kinds, true)


func _add_filter(filter: Filter, label_text: String, options: PackedStringArray, with_all: bool) -> void:
	var label: Label = UiStyle.make_label(TEXT_SIZE)
	label.text = label_text
	_filter_row.add_child(label)
	var select: OptionButton = OptionButton.new()
	select.custom_minimum_size = Vector2(FILTER_WIDTH, ROW_HEIGHT)
	select.add_theme_font_override("font", UiStyle.FONT)
	select.add_theme_font_size_override("font_size", TEXT_SIZE)
	select.get_popup().add_theme_font_override("font", UiStyle.FONT)
	select.get_popup().add_theme_font_size_override("font_size", TEXT_SIZE)
	select.add_theme_stylebox_override("normal", _field_style(false))
	select.add_theme_stylebox_override("hover", _field_style(true))
	select.add_theme_stylebox_override("focus", _field_style(true))
	select.add_theme_stylebox_override("pressed", _field_style(true))
	if with_all:
		select.add_item(tr("LEX_FILTER_ALL"))
	for option: String in options:
		select.add_item(option)
	select.select(_filters.get(filter, 0))
	select.item_selected.connect(func(index: int) -> void:
		set_filter(filter, index)
		_focus_grid())
	_filter_row.add_child(select)


## Einträge des aktuellen Reiters nach Suche, Filtern und Sortierung.
func filtered_entries(tab: int) -> Array[LexiconEntry]:
	var result: Array[LexiconEntry] = []
	for entry: LexiconEntry in _entries[tab]:
		if entry.matches(_search.text if _search != null else "") and _passes_filters(tab, entry):
			result.append(entry)
	if tab == Lexicon.Tab.ITEMS:
		result.sort_custom(Lexicon.sort_by_name if _filters.get(Filter.SORT, 0) == 1 else Lexicon.sort_by_tier)
	return result


func _passes_filters(tab: int, entry: LexiconEntry) -> bool:
	match tab:
		Lexicon.Tab.WEAPONS:
			var class_index: int = _filters.get(Filter.CLASS, 0)
			if class_index > 0 and _class_options[class_index - 1] not in entry.classes:
				return false
			var range_index: int = _filters.get(Filter.RANGE, 0)
			return range_index == 0 or entry.melee == (range_index == 1)
		Lexicon.Tab.ITEMS:
			var tier_index: int = _filters.get(Filter.TIER, 0)
			if tier_index > 0 and entry.tier != _tier_options[tier_index - 1]:
				return false
			var tag_index: int = _filters.get(Filter.TAG, 0)
			return tag_index == 0 or _tag_options[tag_index - 1] in entry.tags
		Lexicon.Tab.ENEMIES:
			var kind_index: int = _filters.get(Filter.KIND, 0)
			return kind_index == 0 or entry.enemy_kind == kind_index - 1
	return true


func _on_search_changed(_text: String) -> void:
	_refresh_grid()
	# Kein Treffer im aktuellen Reiter: zum ersten Reiter mit Treffern wechseln
	if _visible_entries.is_empty():
		for tab: int in Lexicon.tab_count():
			if not filtered_entries(tab).is_empty():
				_set_tab(tab)
				_refresh_grid()
				break


func _refresh_grid() -> void:
	for tab: int in Lexicon.tab_count():
		var title: String = Lexicon.tab_title(tab)
		_tab_buttons[tab].text = title if _search.text.strip_edges() == "" else tr("LEX_TAB_COUNT") % [title, filtered_entries(tab).size()]
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_grid_scroll.scroll_vertical = 0
	_visible_entries = filtered_entries(_tab)
	var selected: LexiconEntry = null
	for entry: LexiconEntry in _visible_entries:
		var card: EntryCard = EntryCard.new()
		card.configure(entry)
		card.selected.connect(_select)
		_grid.add_child(card)
		if entry.id == _selected.get(_tab, &""):
			selected = entry
	if _visible_entries.is_empty():
		_detail.show_message(tr("LEX_NO_RESULTS"), "")
		return
	_select(selected if selected != null else _visible_entries[0])


func _select(entry: LexiconEntry) -> void:
	_selected[_tab] = entry.id
	_detail.show_entry(entry)


func _focus_grid() -> void:
	for child: Node in _grid.get_children():
		var card: EntryCard = child as EntryCard
		if card != null and card.entry.id == _selected.get(_tab, &""):
			_grab_focus.call_deferred(card)
			return
	if _grid.get_child_count() > 0:
		_grab_focus.call_deferred(_grid.get_child(0))


## Verzögert, weil das Raster beim Tippen in der Suche schon wieder neu gebaut sein kann.
func _grab_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree():
		control.grab_focus()


## Für Tests: Karten des aktuellen Rasters.
func get_cards() -> Array[EntryCard]:
	var result: Array[EntryCard] = []
	for child: Node in _grid.get_children():
		result.append(child as EntryCard)
	return result


## Filter setzen (0 = Alle bzw. erste Sortierung) und Raster neu aufbauen.
func set_filter(filter: Filter, index: int) -> void:
	_filters[filter] = index
	_refresh_grid()


func get_detail() -> DetailPanel:
	return _detail


func get_grid_area() -> Control:
	return _grid_scroll


func current_tab() -> int:
	return _tab


func show_tab(tab: int) -> void:
	_show_tab(tab)


func set_search(text: String) -> void:
	_search.text = text
	_on_search_changed(text)
