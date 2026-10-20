class_name GameOverScreen
extends CanvasLayer
## Ende eines Runs: Niederlage oder Sieg mit erreichter Welle und Neustart-Knopf.

const DIM_COLOR: Color = Color("#0B0B12B3")
const TITLE_SIZE: int = 96
const TEXT_SIZE: int = 36
const BUTTON_SIZE: int = 36
const GAP: int = 24

var _title: Label
var _subtitle: Label
var _button: Button


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
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", GAP)
	add_child(box)
	_title = UiStyle.make_label(TITLE_SIZE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_subtitle = UiStyle.make_label(TEXT_SIZE)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	_button = UiStyle.make_button(tr("RESTART"), BUTTON_SIZE)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_restart)
	box.add_child(_button)
	hide()


func show_result(victory: bool, wave_number: int) -> void:
	_title.text = tr("VICTORY") if victory else tr("GAME_OVER")
	_title.add_theme_color_override("font_color", Color("#FFE066") if victory else UiStyle.HP_COLOR)
	_subtitle.text = tr("REACHED_WAVE") % wave_number
	show()
	get_tree().paused = true
	_button.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
