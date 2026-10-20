class_name PauseMenu
extends CanvasLayer
## Pause (Esc / Start): Weiter oder Neustart.

const DIM_COLOR: Color = Color("#0B0B12B3")
const TITLE_SIZE: int = 80
const BUTTON_SIZE: int = 32
const GAP: int = 20

## Solange false (z. B. Game Over sichtbar), lässt sich nicht pausieren.
var enabled: bool = true

var _resume: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", GAP)
	add_child(box)
	var title: Label = UiStyle.make_label(TITLE_SIZE)
	title.text = tr("PAUSE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_resume = UiStyle.make_button(tr("RESUME"), BUTTON_SIZE)
	_resume.pressed.connect(_toggle)
	box.add_child(_resume)
	var restart: Button = UiStyle.make_button(tr("RESTART"), BUTTON_SIZE)
	restart.pressed.connect(_restart)
	box.add_child(restart)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed(&"pause"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	Events.pause_toggled.emit(visible)
	if visible:
		_resume.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
