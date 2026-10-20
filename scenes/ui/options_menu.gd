class_name OptionsMenu
extends CanvasLayer
## Optionen (Hauptmenü und Pause): Lautstärken, Licht, Vollbild, Sprache. Speichert beim Schließen.

signal closed

const DIM_COLOR: Color = Color("#0B0B12CC")
const TITLE_SIZE: int = 56
const TEXT_SIZE: int = 26
const SLIDER_WIDTH: float = 360.0
const GAP: int = 18
const LOCALES: PackedStringArray = ["de", "en"]
const LOCALE_KEYS: PackedStringArray = ["LANG_DE", "LANG_EN"]
const VOLUME_STEP: float = 0.05

var _first_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func open() -> void:
	for child: Node in get_children():
		child.queue_free()
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = UiStyle.make_panel()
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	panel.add_child(box)
	var title: Label = UiStyle.make_label(TITLE_SIZE)
	title.text = tr("OPTIONS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", GAP * 2)
	grid.add_theme_constant_override("v_separation", GAP)
	box.add_child(grid)
	_first_focus = null
	for bus_name: String in SaveManager.VOLUME_KEYS:
		_label(grid, {"Master": "OPT_MASTER", "Music": "OPT_MUSIC", "SFX": "OPT_SFX"}[bus_name])
		var slider: HSlider = HSlider.new()
		slider.custom_minimum_size = Vector2(SLIDER_WIDTH, TEXT_SIZE)
		slider.max_value = 1.0
		slider.step = VOLUME_STEP
		slider.value = SaveManager.get_volume(bus_name)
		slider.value_changed.connect(func(v: float) -> void: SaveManager.set_volume(bus_name, v))
		grid.add_child(slider)
		if _first_focus == null:
			_first_focus = slider

	_label(grid, "OPT_LIGHTING")
	grid.add_child(_toggle(SaveManager.LIGHTING_KEY, true, func(_on: bool) -> void: pass))
	_label(grid, "OPT_FULLSCREEN")
	grid.add_child(_toggle(SaveManager.FULLSCREEN_KEY, false, func(_on: bool) -> void: SaveManager.apply_options()))
	_label(grid, "OPT_LANGUAGE")
	var language: OptionButton = OptionButton.new()
	language.add_theme_font_override("font", UiStyle.FONT)
	language.add_theme_font_size_override("font_size", TEXT_SIZE)
	for key: String in LOCALE_KEYS:
		language.add_item(tr(key))
	language.selected = maxi(0, LOCALES.find(SaveManager.get_value(SaveManager.OPTIONS_SECTION, SaveManager.LOCALE_KEY, SaveManager.DEFAULT_LOCALE)))
	language.item_selected.connect(_on_language_selected)
	grid.add_child(language)

	var back: Button = UiStyle.make_button(tr("BACK"), TEXT_SIZE)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	box.add_child(back)
	show()
	_first_focus.call_deferred("grab_focus")


func close() -> void:
	SaveManager.save_game()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func _label(parent: Control, key: String) -> void:
	var label: Label = UiStyle.make_label(TEXT_SIZE)
	label.text = tr(key)
	parent.add_child(label)


func _toggle(key: String, default: bool, on_change: Callable) -> CheckButton:
	var toggle: CheckButton = CheckButton.new()
	toggle.button_pressed = SaveManager.get_value(SaveManager.OPTIONS_SECTION, key, default)
	toggle.toggled.connect(func(on: bool) -> void:
		SaveManager.set_value(SaveManager.OPTIONS_SECTION, key, on)
		on_change.call(on))
	return toggle


func _on_language_selected(index: int) -> void:
	SaveManager.set_value(SaveManager.OPTIONS_SECTION, SaveManager.LOCALE_KEY, LOCALES[index])
	SaveManager.apply_options()
	open.call_deferred()
