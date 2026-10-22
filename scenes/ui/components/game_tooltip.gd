class_name GameTooltip
extends CanvasLayer
## Hover-Tooltip mit BBCode für Maus und Gamepad-Fokus (Phase 15, Paket 4). Eine Instanz unter der Wurzel des
## Szenenbaums dient allen Bildschirmen. Der Tooltip hängt am Element (nicht am Mauszeiger) und wird so platziert,
## dass er nie aus dem sichtbaren Bereich ragt: rechts, sonst links, sonst unter/über dem Element, zuletzt geklemmt.

const LAYER: int = 120
const WIDTH: float = 480.0
const TEXT_SIZE: int = 20
## Abstand zum Element und Mindestabstand zum Bildschirmrand.
const GAP: float = 10.0
const MARGIN: float = 8.0
const BORDER_COLOR: Color = Color("#4A90E2")

static var _instance: GameTooltip

var _panel: PanelContainer
var _text: RichTextLabel
var _owner: Control


## Tooltip an ein Element hängen. `builder` liefert den BBCode erst beim Anzeigen (aktuelle Werte).
## mouse: bei Hover; focus: bei Tastatur-/Gamepad-Fokus.
static func attach(control: Control, builder: Callable, mouse: bool = true, focus: bool = true) -> void:
	if mouse:
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		control.mouse_entered.connect(func() -> void: _show_on(control, builder))
		control.mouse_exited.connect(func() -> void: _hide_on(control))
	if focus:
		control.focus_entered.connect(func() -> void: _show_on(control, builder))
		control.focus_exited.connect(func() -> void: _hide_on(control))
	control.tree_exiting.connect(func() -> void: _hide_on(control))
	control.visibility_changed.connect(func() -> void:
		if not control.is_visible_in_tree():
			_hide_on(control))


## Gerade sichtbarer Tooltip-Text (leer, wenn keiner offen ist); für Tests und Screenshots.
static func current_text() -> String:
	if _instance == null or not is_instance_valid(_instance) or not _instance._panel.visible:
		return ""
	return _instance._text.text


static func current_rect() -> Rect2:
	if _instance == null or not is_instance_valid(_instance) or not _instance._panel.visible:
		return Rect2()
	return _instance._panel.get_global_rect()


## Position des Tooltips: rechts neben dem Anker, sonst links, sonst darunter oder darüber; immer im Bereich `area`.
static func place(anchor: Rect2, tip_size: Vector2, area: Rect2) -> Vector2:
	var left_edge: float = area.position.x + MARGIN
	var right_edge: float = area.end.x - MARGIN
	var top_edge: float = area.position.y + MARGIN
	var bottom_edge: float = area.end.y - MARGIN
	var pos: Vector2 = Vector2(anchor.end.x + GAP, anchor.position.y)
	if pos.x + tip_size.x > right_edge:
		pos.x = anchor.position.x - GAP - tip_size.x
		if pos.x < left_edge:
			# Weder rechts noch links Platz: unter (oder über) dem Element, horizontal zentriert
			pos.x = anchor.get_center().x - tip_size.x * 0.5
			pos.y = anchor.end.y + GAP
			if pos.y + tip_size.y > bottom_edge:
				pos.y = anchor.position.y - GAP - tip_size.y
	pos.x = clampf(pos.x, left_edge, maxf(left_edge, right_edge - tip_size.x))
	pos.y = clampf(pos.y, top_edge, maxf(top_edge, bottom_edge - tip_size.y))
	return pos


static func _get_instance(tree: SceneTree) -> GameTooltip:
	if _instance == null or not is_instance_valid(_instance):
		_instance = GameTooltip.new()
		tree.root.add_child(_instance)
	return _instance


static func _show_on(control: Control, builder: Callable) -> void:
	if not control.is_inside_tree() or not control.is_visible_in_tree():
		return
	var text: String = builder.call()
	if text == "":
		return
	_get_instance(control.get_tree())._open(control, text)


static func _hide_on(control: Control) -> void:
	if _instance != null and is_instance_valid(_instance) and _instance._owner == control:
		_instance._close()


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.panel_style()
	style.bg_color = UiStyle.PANEL_COLOR.lightened(0.02)
	style.bg_color.a = 0.97
	style.border_color = BORDER_COLOR
	style.set_border_width_all(UiStyle.BORDER_WIDTH)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH, 0.0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("normal_font", UiStyle.FONT)
	_text.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_text.add_theme_constant_override("outline_size", 0)
	_panel.add_child(_text)
	_panel.hide()


func _open(control: Control, text: String) -> void:
	_owner = control
	_text.text = text
	# Erst nach dem Umbruch des Textes (nächster Frame) zeigen, damit die Größe für die Platzierung stimmt.
	_panel.modulate.a = 0.0
	_panel.show()
	_panel.reset_size()
	_reposition()


func _close() -> void:
	_owner = null
	_panel.hide()


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	if _owner == null or not is_instance_valid(_owner) or not _owner.is_visible_in_tree():
		_close()
		return
	_reposition()
	_panel.modulate.a = 1.0


func _reposition() -> void:
	_panel.size = _panel.get_combined_minimum_size()
	var area: Rect2 = _panel.get_viewport_rect()
	_panel.position = place(_owner.get_global_rect(), _panel.size, area)
