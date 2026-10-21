class_name DetailPanel
extends PanelContainer
## Detailpanel mit fester Größe: Kopf (Icon, Name, Einordnung) bleibt stehen, der Rest scrollt nur im Panel.
## Zeigt einen LexiconEntry; gesperrte Einträge nur als Silhouette mit Name und Freischaltbedingung.

const ICON_SIZE: Vector2 = Vector2(120, 120)
const TITLE_SIZE: int = 36
const SUBTITLE_SIZE: int = 20
const HEADING_SIZE: int = 22
const TEXT_SIZE: int = 20
const GAP: int = 10
const SECTION_GAP: int = 4
const LOCKED_COLOR: Color = Color("#000000")
const HEADING_COLOR: Color = Color("#FFD43B")
const SUBTITLE_COLOR: Color = Color("#C9C3D6")
## Pixel pro Sekunde beim Scrollen mit Stick oder Tasten.
const SCROLL_SPEED: float = 900.0
## Schräglage der Kursivschrift (die runde Schrift hat keinen eigenen Kursivschnitt).
const ITALIC_SLANT: float = 0.2

static var _italic: FontVariation

var _icon: TextureRect
var _title: Label
var _subtitle: Label
var _scroll: ScrollContainer
var _body: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_style())
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clip_contents = true
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	add_child(box)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", GAP * 2)
	header.custom_minimum_size = Vector2(0.0, ICON_SIZE.y)
	box.add_child(header)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_icon)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title = UiStyle.make_label(TITLE_SIZE)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	titles.add_child(_title)
	_subtitle = UiStyle.make_label(SUBTITLE_SIZE, SUBTITLE_COLOR)
	_subtitle.clip_text = true
	titles.add_child(_subtitle)
	box.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", GAP)
	_scroll.add_child(_body)


func show_entry(entry: LexiconEntry) -> void:
	_clear()
	_icon.texture = entry.icon
	_icon.modulate = LOCKED_COLOR if entry.locked else Color.WHITE
	_title.text = entry.title
	_title.add_theme_color_override("font_color", entry.color if not entry.locked else UiStyle.TEXT_COLOR)
	if entry.locked:
		_subtitle.text = TextFormat.t("LOCKED")
		add_section(TextFormat.t("LEX_UNLOCK"), entry.lock_text)
		return
	_subtitle.text = entry.subtitle
	if entry.lore != "":
		add_text(Lexicon.lore_bbcode(entry.lore))
	for section: LexiconSection in entry.sections:
		if section.is_table():
			add_table(section.title, section.table)
		else:
			add_section(section.title, section.text)


## Nur ein Hinweistext (z. B. "Keine Treffer").
func show_message(title: String, text: String) -> void:
	_clear()
	_icon.texture = null
	_title.text = title
	_title.add_theme_color_override("font_color", UiStyle.TEXT_COLOR)
	_subtitle.text = ""
	add_text(text)


func add_section(heading: String, bbcode: String) -> void:
	var box: VBoxContainer = _section_box(heading)
	box.add_child(_text(bbcode))


func add_table(heading: String, rows: Array[PackedStringArray]) -> void:
	var box: VBoxContainer = _section_box(heading)
	var table: StatTable = StatTable.new()
	table.set_rows(rows)
	box.add_child(table)


func add_text(bbcode: String) -> void:
	_body.add_child(_text(bbcode))


func scroll_by(pixels: float) -> void:
	_scroll.scroll_vertical += roundi(pixels)


func get_scroll() -> ScrollContainer:
	return _scroll


func _section_box(heading: String) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", SECTION_GAP)
	_body.add_child(box)
	var label: Label = UiStyle.make_label(HEADING_SIZE, HEADING_COLOR)
	label.text = heading
	box.add_child(label)
	return box


func _text(bbcode: String) -> RichTextLabel:
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	text.add_theme_font_override("normal_font", UiStyle.FONT)
	text.add_theme_font_override("italics_font", _italic_font())
	text.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	text.add_theme_font_size_override("italics_font_size", TEXT_SIZE)
	text.text = bbcode
	return text


static func _italic_font() -> FontVariation:
	if _italic == null:
		_italic = FontVariation.new()
		_italic.base_font = UiStyle.FONT
		_italic.variation_transform = Transform2D(Vector2.RIGHT, Vector2(ITALIC_SLANT, 1.0), Vector2.ZERO)
	return _italic


func _clear() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_scroll.scroll_vertical = 0
