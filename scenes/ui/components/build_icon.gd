class_name BuildIcon
extends PanelContainer
## Icon einer besessenen Waffe oder eines Items mit Rahmen in Tier-Farbe und optionaler Anzahl.
## Fokussierbar (Gamepad), hebt den Fokus mit hellerem Rahmen hervor und zeigt einen GameTooltip.

const DEFAULT_SIZE: Vector2 = Vector2(56, 56)
const COUNT_SIZE: int = 20
const FOCUS_COLOR: Color = Color("#FFFFFF")
## Innenabstand zwischen Rahmen und Icon (kleiner als bei Panels, damit viele Items in eine Zeile passen).
const PADDING: int = 4

var _style: StyleBoxFlat
var _border: Color


## `tooltip` liefert den BBCode beim Anzeigen (aktuelle Werte).
func _init(texture: Texture2D = null, tier: int = 1, count: int = 1, tooltip: Callable = Callable(), icon_size: Vector2 = DEFAULT_SIZE) -> void:
	_border = UiStyle.tier_color(tier)
	_style = UiStyle.panel_style()
	_style.border_color = _border
	_style.set_border_width_all(UiStyle.BORDER_WIDTH)
	_style.set_content_margin_all(PADDING)
	add_theme_stylebox_override("panel", _style)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	if count > 1:
		var label: Label = UiStyle.make_label(COUNT_SIZE)
		label.text = "x%d" % count
		label.size_flags_horizontal = Control.SIZE_SHRINK_END
		label.size_flags_vertical = Control.SIZE_SHRINK_END
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	focus_entered.connect(func() -> void: _style.border_color = FOCUS_COLOR)
	focus_exited.connect(func() -> void: _style.border_color = _border)
	if tooltip.is_valid():
		GameTooltip.attach(self, tooltip)
