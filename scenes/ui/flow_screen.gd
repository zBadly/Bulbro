class_name FlowScreen
extends CanvasLayer
## Basis der Bildschirme nach einer Welle (Karton, Level-up, Shop): abgedunkelter Hintergrund,
## zentrierter Inhalt, läuft auch bei pausiertem Spiel. Unterklassen bauen ihren Inhalt in open().

const DIM_COLOR: Color = Color("#0B0B12CC")
const TITLE_SIZE: int = 56
const SUBTITLE_SIZE: int = 28
const GAP: int = 24

var player: Player

var _content: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", GAP)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_content)
	hide()


func open() -> void:
	show()


func close() -> void:
	hide()
	_clear()


## Alten Inhalt sofort aus dem Layout nehmen, damit der Neuaufbau keinen Frame lang doppelt zentriert wird.
func _clear() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _add_title(text: String, size: int = TITLE_SIZE, color: Color = UiStyle.TEXT_COLOR) -> Label:
	var label: Label = UiStyle.make_label(size, color)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(label)
	return label


func _add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP)
	_content.add_child(row)
	return row


## Fokus für Tastatur/Gamepad setzen, sobald der neue Inhalt im Baum ist.
func _focus_later(control: Control) -> void:
	if control != null:
		control.call_deferred("grab_focus")
