class_name PauseMenu
extends CanvasLayer
## Pause (Esc / Start): Weiter, Optionen, Aufgeben; darunter Waffen und Items mit Tooltips.

signal give_up_requested

const DIM_COLOR: Color = Color("#0B0B12B3")
const TITLE_SIZE: int = 80
const BUTTON_SIZE: int = 32
const BUTTON_WIDTH: float = 300.0
const GAP: int = 20

## Solange false (z. B. Run-Ende sichtbar), lässt sich nicht pausieren.
var enabled: bool = true
## Von der Arena gesetzt (für die Build-Übersicht).
var player: Player

var _box: VBoxContainer
var _resume: Button
var _options: OptionsMenu
var _overview: BuildOverview


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", GAP)
	center.add_child(_box)
	var title: Label = UiStyle.make_label(TITLE_SIZE)
	title.text = tr("PAUSE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_resume = _button(tr("RESUME"), _toggle)
	_button(tr("MENU_OPTIONS"), _open_options)
	_button(tr("GIVE_UP"), _give_up)
	_options = OptionsMenu.new()
	_options.layer = layer + 1
	add_child(_options)
	_options.closed.connect(func() -> void: _resume.grab_focus())
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible:
		return
	if enabled and GameState.phase == GameState.Phase.WAVE and event.is_action_pressed(&"pause"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	Events.pause_toggled.emit(visible)
	if visible:
		_rebuild_overview()
		_resume.grab_focus()


## Waffen und Items bei jedem Öffnen neu aufbauen (Kills und Schaden ändern sich in der Welle).
func _rebuild_overview() -> void:
	if _overview != null:
		_box.remove_child(_overview)
		_overview.queue_free()
		_overview = null
	if player != null:
		_overview = BuildOverview.new(player)
		_box.add_child(_overview)


func _open_options() -> void:
	_options.open()


func _give_up() -> void:
	_toggle()
	give_up_requested.emit()


func _button(text: String, callback: Callable) -> Button:
	var button: Button = UiStyle.make_button(text, BUTTON_SIZE)
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	_box.add_child(button)
	return button
