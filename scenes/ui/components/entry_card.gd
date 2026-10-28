class_name EntryCard
extends Button
## Karte im Lexikon-Raster: Icon und Name mit Rahmen in der Farbe des Eintrags (z. B. Tier-Farbe).
## Feste Größe, Name höchstens zwei Zeilen; gesperrte Einträge zeigen ein Schloss und (ohne "Alles anzeigen") das Icon als Silhouette.
## Meldet `selected`, sobald die Karte den Fokus bekommt (Maus, Tastatur, Gamepad).

signal selected(entry: LexiconEntry)

const CARD_SIZE: Vector2 = Vector2(150, 184)
const ICON_SIZE: Vector2 = Vector2(96, 96)
const NAME_SIZE: int = 19
const NAME_LINES: int = 2
## Kleinste Schriftgröße, damit lange Namen nicht mitten im Wort umbrechen.
const MIN_NAME_SIZE: int = 12
const BORDER_WIDTH: int = 3
const FOCUS_BORDER_WIDTH: int = 5
const GAP: int = 6
const PADDING: int = 8
const LOCKED_COLOR: Color = Color("#000000")
const LOCKED_TEXT_COLOR: Color = Color("#8A8A8A")
const LOCK_TEXTURE: Texture2D = preload("res://art/ui/lock.svg")
const LOCK_SIZE: Vector2 = Vector2(30, 30)

var entry: LexiconEntry

var _icon: TextureRect
var _name: Label
## Schloss-Abzeichen oben rechts für gesperrte Einträge.
var _lock: TextureRect


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clip_contents = true
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = PADDING
	box.offset_top = PADDING
	box.offset_right = -PADDING
	box.offset_bottom = -PADDING
	box.add_theme_constant_override("separation", GAP)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_icon)
	_name = UiStyle.make_label(NAME_SIZE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = NAME_LINES
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name)
	_lock = TextureRect.new()
	_lock.texture = LOCK_TEXTURE
	_lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lock.size = LOCK_SIZE
	_lock.position = Vector2(CARD_SIZE.x - LOCK_SIZE.x - PADDING, PADDING)
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.visible = false
	add_child(_lock)
	focus_entered.connect(func() -> void: selected.emit(entry))


## show_all: gesperrte Einträge in voller Farbe; das Schloss-Abzeichen bleibt.
func configure(lexicon_entry: LexiconEntry, show_all: bool = false) -> void:
	entry = lexicon_entry
	var masked: bool = entry.is_hidden(show_all)
	_icon.texture = entry.icon
	_icon.modulate = LOCKED_COLOR if masked else Color.WHITE
	_lock.visible = entry.locked
	_name.text = entry.title
	_fit_name()
	_name.add_theme_color_override("font_color", LOCKED_TEXT_COLOR if masked else entry.color)
	var border: Color = LOCKED_TEXT_COLOR if masked else entry.color
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = UiStyle.panel_style()
		var active: bool = state in ["hover", "focus", "pressed"]
		style.bg_color = UiStyle.BUTTON_FOCUS_COLOR if active else UiStyle.BUTTON_COLOR
		style.border_color = UiStyle.TEXT_COLOR if state == "focus" else border
		style.set_border_width_all(FOCUS_BORDER_WIDTH if state == "focus" else BORDER_WIDTH)
		add_theme_stylebox_override(state, style)


## Für Tests: Schloss-Abzeichen sichtbar?
func is_lock_visible() -> bool:
	return _lock.visible


## Verkleinert die Schrift, bis jedes Wort (auch Teile mit Bindestrich) in eine Zeile passt.
func _fit_name() -> void:
	var width: float = CARD_SIZE.x - 2.0 * PADDING - UiStyle.TEXT_OUTLINE
	var words: PackedStringArray = entry.title.replace("-", "- ").split(" ", false)
	var font_size: int = NAME_SIZE
	while font_size > MIN_NAME_SIZE:
		var fits: bool = true
		for word: String in words:
			if UiStyle.FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width:
				fits = false
				break
		if fits:
			break
		font_size -= 1
	_name.add_theme_font_size_override("font_size", font_size)
