class_name GameOverScreen
extends CanvasLayer

signal endless_requested
## Run-Ende (Sieg, Niederlage, Tod im Endlos-Modus) mit zwei Reitern (Phase 15, Paket 5):
## "Übersicht" (Build mit Tooltips, Freischaltungen) und "Statistiken" (RunStatsPanel). Reiter per Maus oder Q/E bzw.
## LB/RB; die Buttons unten bleiben in beiden Reitern sichtbar: Endlos weiterspielen (nur nach dem Sieg), Nochmal,
## Neuer Run, Hauptmenü. Feste Größen für 1920 x 1080, passt skaliert auch in 1280 x 720.

const RUN_SETUP_SCENE: String = "res://scenes/ui/run_setup.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const DIM_COLOR: Color = Color("#0B0B12F2")
const HINT_COLOR: Color = Color("#C9C3D6")
const TITLE_SIZE: int = 80
const TEXT_SIZE: int = 30
const SMALL_SIZE: int = 22
const HINT_SIZE: int = 18
const BUTTON_SIZE: int = 30
const TAB_SIZE: int = 24
const TAB_WIDTH: float = 240.0
const TAB_HEIGHT: float = 48.0
const PORTRAIT_SIZE: Vector2 = Vector2(96, 128)
const MARGIN: int = 36
const GAP: int = 14
const VICTORY_COLOR: Color = Color("#FFE066")
const UNLOCK_COLOR: Color = Color("#7ED957")

enum Tab { OVERVIEW, STATS }

var tab: Tab = Tab.OVERVIEW
var stats_panel: RunStatsPanel

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _first_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func show_result(victory: bool, wave_number: int, player: Player) -> void:
	for child: Node in get_children():
		child.queue_free()
	_tab_buttons.clear()
	_pages.clear()
	var unlocked: Array[ChallengeData] = Unlocks.evaluate_run_end(victory)
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	margin.add_child(box)

	var title: Label = _label(tr("VICTORY") if victory else tr("GAME_OVER"), TITLE_SIZE, VICTORY_COLOR if victory else UiStyle.HP_COLOR)
	box.add_child(title)
	box.add_child(_build_tabs())
	var pages: Control = Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(pages)
	_add_page(pages, _build_overview(wave_number, player, unlocked))
	stats_panel = RunStatsPanel.new(player)
	_add_page(pages, stats_panel)
	box.add_child(_build_buttons(victory))
	show_tab(Tab.OVERVIEW)
	show()
	get_tree().paused = true
	_first_button.grab_focus()


func show_tab(index: Tab) -> void:
	tab = index
	for i: int in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].set_pressed_no_signal(i == index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _pages.is_empty():
		return
	if event.is_action_pressed(&"tab_prev") or event.is_action_pressed(&"tab_next"):
		show_tab(Tab.STATS if tab == Tab.OVERVIEW else Tab.OVERVIEW)
	elif event.is_action_pressed(&"stats_sort") and tab == Tab.STATS:
		stats_panel.cycle_sort()
	else:
		return
	get_viewport().set_input_as_handled()


func _build_tabs() -> HBoxContainer:
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", GAP / 2)
	var group: ButtonGroup = ButtonGroup.new()
	for key: String in ["RUN_TAB_OVERVIEW", "RUN_TAB_STATS"]:
		var button: Button = UiStyle.make_button(tr(key), TAB_SIZE)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(TAB_WIDTH, TAB_HEIGHT)
		var pressed: StyleBoxFlat = button.get_theme_stylebox("pressed").duplicate()
		pressed.bg_color = UiStyle.BUTTON_FOCUS_COLOR
		pressed.border_color = UiStyle.SPARK_COLOR
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("hover_pressed", pressed)
		button.pressed.connect(show_tab.bind(_tab_buttons.size()))
		tabs.add_child(button)
		_tab_buttons.append(button)
	var hint: Label = UiStyle.make_label(HINT_SIZE, HINT_COLOR)
	hint.text = tr("LEX_TAB_HINT")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tabs.add_child(hint)
	return tabs


func _add_page(parent: Control, page: Control) -> void:
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(page)
	_pages.append(page)


## Übersicht: Porträt, erreichte Welle, Build mit Tooltips, Freischaltungen (scrollt bei vielen Items).
func _build_overview(wave_number: int, player: Player, unlocked: Array[ChallengeData]) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", GAP)
	scroll.add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", GAP)
	box.add_child(header)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = GameState.character.get_portrait()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(portrait)
	var info: VBoxContainer = VBoxContainer.new()
	header.add_child(info)
	var who: Label = UiStyle.make_label(TEXT_SIZE)
	who.text = tr("RUN_END_CHARACTER") % [tr(GameState.character.name_key), tr(GameState.difficulty.name_key)]
	info.add_child(who)
	var reached: Label = UiStyle.make_label(TEXT_SIZE)
	if GameState.endless:
		reached.text = tr("REACHED_ENDLESS_WAVE") % [GameState.endless_level(), wave_number]
	else:
		reached.text = tr("REACHED_WAVE") % wave_number
	info.add_child(reached)
	var stats: Label = UiStyle.make_label(SMALL_SIZE)
	stats.text = tr("RUN_END_STATS") % [GameState.level, GameState.total_sparks_collected, GameState.run_stats.enemies_killed]
	info.add_child(stats)

	# Waffen und Items mit Tooltips (Werte, Set-Boni, Kills und Schaden dieses Runs)
	var build: BuildOverview = BuildOverview.new(player)
	build.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(build)
	for challenge: ChallengeData in unlocked:
		box.add_child(_label(tr("RUN_END_UNLOCKED") % challenge.reward_name(), TEXT_SIZE, UNLOCK_COLOR))
	return scroll


func _build_buttons(victory: bool) -> HBoxContainer:
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", GAP)
	var endless: Button = null
	if victory and not GameState.endless:
		endless = _button(buttons, tr("ENDLESS_CONTINUE"), _continue_endless)
	var retry: Button = _button(buttons, tr("RUN_END_RETRY"), _restart)
	_button(buttons, tr("RUN_END_NEW_RUN"), _change_scene.bind(RUN_SETUP_SCENE))
	_button(buttons, tr("RUN_END_MAIN_MENU"), _change_scene.bind(MAIN_MENU_SCENE))
	_first_button = endless if endless != null else retry
	return buttons


func _label(text: String, size: int, color: Color = UiStyle.TEXT_COLOR) -> Label:
	var label: Label = UiStyle.make_label(size, color)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = UiStyle.make_button(text, BUTTON_SIZE)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _continue_endless() -> void:
	hide()
	for child: Node in get_children():
		child.queue_free()
	_pages.clear()
	endless_requested.emit()


func _restart() -> void:
	get_tree().paused = false
	GameState.restore_run_setup()
	get_tree().reload_current_scene()


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
