class_name OfferCard
extends PanelContainer
## Karte für ein Angebot (Item, Waffe, Upgrade) mit fester Struktur, damit alle Karten einer Reihe gleich aussehen:
## Kopf (Icon, Name in Tier-Farbe mit max. 2 Zeilen, Tier), Mitte (Beschreibung; zu langer Text wird kleiner
## statt die Karte zu strecken), Fuß (Preis + Nebenaktion wie Sperren, darunter die Aktions-Buttons) am unteren Rand.
## Meldet `focused`, wenn die Maus darüber fährt oder ein Button den Fokus bekommt (für die Stat-Vorschau).

signal focused(card: OfferCard)

const CARD_SIZE: Vector2 = Vector2(280, 500)
const ICON_SIZE: Vector2 = Vector2(64, 64)
const TITLE_SIZE: int = 26
const TITLE_LINES: int = 2
const TIER_SIZE: int = 18
const DESC_SIZE: int = 20
## Kleinste Schriftgröße der Beschreibung, bevor sie abgeschnitten wird.
const MIN_DESC_SIZE: int = 12
const BUTTON_SIZE: int = 22
const SIDE_BUTTON_SIZE: int = 18
const FOOTER_SIZE: int = 20
## Standardhöhe des Hinweis-Fußes in Zeilen; längerer Text wird kleiner (wie die Beschreibung).
const FOOTER_LINES: int = 4
const BORDER_WIDTH: int = 4
## Einzigartige Karten: dickere Goldkontur mit leichtem Schein.
const UNIQUE_EXTRA_BORDER: int = 2
const UNIQUE_GLOW_SIZE: int = 10
const UNIQUE_GLOW_ALPHA: float = 0.45
const GAP: int = 8

## Beliebige Nutzdaten des Aufrufers (z. B. ItemData oder UpgradeData).
var payload: Variant
## Stat-Änderungen dieses Angebots für die Vorher/Nachher-Vorschau.
var preview_modifiers: Array[StatModifier] = []

var _icon: TextureRect
var _title: Label
var _tier_label: Label
var _description: RichTextLabel
var _footer: RichTextLabel
var _price_row: HBoxContainer
var _price: Label
var _actions: VBoxContainer


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	# Feste Höhe: die Reihe darf die Karte nicht strecken
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	add_child(box)

	# Kopf
	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.add_child(_icon)
	_title = UiStyle.make_label(TITLE_SIZE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.max_lines_visible = TITLE_LINES
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.custom_minimum_size = Vector2(0.0, UiStyle.FONT.get_height(TITLE_SIZE) * TITLE_LINES)
	box.add_child(_title)
	_tier_label = UiStyle.make_label(TIER_SIZE)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_tier_label)

	# Mitte
	_description = RichTextLabel.new()
	_description.bbcode_enabled = true
	_description.fit_content = false
	_description.scroll_active = false
	_description.clip_contents = true
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description.add_theme_font_override("normal_font", UiStyle.FONT)
	_description.resized.connect(_fit_description)
	box.add_child(_description)

	# Fuß
	_footer = RichTextLabel.new()
	_footer.bbcode_enabled = true
	_footer.fit_content = false
	_footer.scroll_active = false
	_footer.clip_contents = true
	_footer.add_theme_font_override("normal_font", UiStyle.FONT)
	_footer.resized.connect(_fit_footer)
	_footer.hide()
	box.add_child(_footer)
	_price_row = HBoxContainer.new()
	_price_row.add_theme_constant_override("separation", GAP)
	_price_row.hide()
	box.add_child(_price_row)
	_price = UiStyle.make_label(TITLE_SIZE, UiStyle.SPARK_COLOR)
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_price_row.add_child(_price)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", GAP)
	box.add_child(_actions)
	mouse_entered.connect(func() -> void: focused.emit(self))


func configure(icon: Texture2D, title: String, tier: int, description_bbcode: String) -> void:
	_icon.texture = icon
	_icon.visible = icon != null
	_title.text = title
	var color: Color = UiStyle.tier_color(tier)
	_title.add_theme_color_override("font_color", color)
	_tier_label.text = TextFormat.tier_name(tier)
	_tier_label.add_theme_color_override("font_color", color)
	_description.text = description_bbcode
	_fit_description()
	var style: StyleBoxFlat = UiStyle.panel_style()
	style.border_color = color
	style.set_border_width_all(BORDER_WIDTH)
	if tier == ItemData.UNIQUE_TIER:
		style.bg_color = style.bg_color.lerp(color, UiStyle.UNIQUE_CARD_TINT)
		style.set_border_width_all(BORDER_WIDTH + UNIQUE_EXTRA_BORDER)
		style.shadow_color = Color(color, UNIQUE_GLOW_ALPHA)
		style.shadow_size = UNIQUE_GLOW_SIZE
	add_theme_stylebox_override("panel", style)


## Hinweis über den Buttons mit fester Höhe (z. B. Synergie der Startwaffe), damit alle Karten gleich aufgebaut sind.
func set_footer(bbcode: String, lines: int = FOOTER_LINES) -> void:
	_footer.custom_minimum_size = Vector2(0.0, UiStyle.FONT.get_height(FOOTER_SIZE) * lines)
	_footer.text = bbcode
	_footer.show()
	_fit_footer()


func set_price(price: int, affordable: bool) -> void:
	set_status(tr("PRICE") % price, UiStyle.SPARK_COLOR if affordable else UiStyle.HP_COLOR)


## Text an der Preisstelle (z. B. "Verkauft"), damit der Fuß gleich aufgebaut bleibt.
func set_status(text: String, color: Color) -> void:
	_price.text = text
	_price.add_theme_color_override("font_color", color)
	_price_row.show()


func add_action(text: String, callback: Callable, disabled: bool = false) -> Button:
	var button: Button = _make_button(text, BUTTON_SIZE, callback, disabled)
	_actions.add_child(button)
	return button


## Kleine Aktion neben dem Preis (Sperren).
func add_side_action(text: String, callback: Callable) -> Button:
	var button: Button = _make_button(text, SIDE_BUTTON_SIZE, callback, false)
	_price_row.add_child(button)
	_price_row.show()
	return button


func first_button() -> Button:
	for child: Node in _actions.get_children():
		var button: Button = child as Button
		if button != null and not button.disabled:
			return button
	return null


## Aktuelle Schriftgröße der Beschreibung (nach dem Verkleinern).
func get_description_font_size() -> int:
	return _description.get_theme_font_size("normal_font_size")


func _make_button(text: String, font_size: int, callback: Callable, disabled: bool) -> Button:
	var button: Button = UiStyle.make_button(text, font_size)
	button.disabled = disabled
	button.pressed.connect(callback)
	button.focus_entered.connect(func() -> void: focused.emit(self))
	return button


## Verkleinert die Schrift der Beschreibung, bis der Text in den verfügbaren Platz passt.
func _fit_footer() -> void:
	var available: float = _footer.size.y
	for font_size: int in range(FOOTER_SIZE, MIN_DESC_SIZE - 1, -1):
		_footer.add_theme_font_size_override("normal_font_size", font_size)
		if available <= 0.0 or _footer.get_content_height() <= available:
			return


func _fit_description() -> void:
	var available: float = _description.size.y
	for font_size: int in range(DESC_SIZE, MIN_DESC_SIZE - 1, -1):
		_description.add_theme_font_size_override("normal_font_size", font_size)
		if available <= 0.0 or _description.get_content_height() <= available:
			return
