class_name OfferCard
extends PanelContainer
## Karte für ein Angebot (Item, Waffe, Upgrade): Icon, Name in Tier-Farbe, Beschreibung, Aktions-Buttons.
## Meldet `focused`, wenn die Maus darüber fährt oder ein Button den Fokus bekommt (für die Stat-Vorschau).

signal focused(card: OfferCard)

const CARD_SIZE: Vector2 = Vector2(280, 330)
const ICON_SIZE: Vector2 = Vector2(64, 64)
const TITLE_SIZE: int = 26
const TIER_SIZE: int = 18
const DESC_SIZE: int = 20
const BUTTON_SIZE: int = 22
const BORDER_WIDTH: int = 4
const GAP: int = 8

## Beliebige Nutzdaten des Aufrufers (z. B. ItemData oder UpgradeData).
var payload: Variant
## Stat-Änderungen dieses Angebots für die Vorher/Nachher-Vorschau.
var preview_modifiers: Array[StatModifier] = []

var _icon: TextureRect
var _title: Label
var _tier_label: Label
var _description: RichTextLabel
var _price: Label
var _actions: VBoxContainer


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	add_child(box)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.add_child(_icon)
	_title = UiStyle.make_label(TITLE_SIZE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_tier_label = UiStyle.make_label(TIER_SIZE)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_tier_label)
	_description = RichTextLabel.new()
	_description.bbcode_enabled = true
	_description.fit_content = true
	_description.scroll_active = false
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description.add_theme_font_override("normal_font", UiStyle.FONT)
	_description.add_theme_font_size_override("normal_font_size", DESC_SIZE)
	box.add_child(_description)
	_price = UiStyle.make_label(TITLE_SIZE, UiStyle.SPARK_COLOR)
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price.hide()
	box.add_child(_price)
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
	var style: StyleBoxFlat = UiStyle.panel_style()
	style.border_color = color
	style.set_border_width_all(BORDER_WIDTH)
	add_theme_stylebox_override("panel", style)


func set_price(price: int, affordable: bool) -> void:
	_price.text = tr("PRICE") % price
	_price.add_theme_color_override("font_color", UiStyle.SPARK_COLOR if affordable else UiStyle.HP_COLOR)
	_price.show()


func add_action(text: String, callback: Callable, disabled: bool = false) -> Button:
	var button: Button = UiStyle.make_button(text, BUTTON_SIZE)
	button.disabled = disabled
	button.pressed.connect(callback)
	button.focus_entered.connect(func() -> void: focused.emit(self))
	_actions.add_child(button)
	return button


func first_button() -> Button:
	for child: Node in _actions.get_children():
		var button: Button = child as Button
		if button != null and not button.disabled:
			return button
	return null
