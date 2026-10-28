class_name UiStyle
extends RefCounted
## Gemeinsame UI-Optik (GDD Abschnitt 12, docs/ART_STYLE.md): dunkle runde Panels, dicke runde Schrift.

const FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const PANEL_COLOR: Color = Color("#1B1B24D9")
const OUTLINE_COLOR: Color = Color("#2A1E2E")
const TEXT_COLOR: Color = Color("#F4F0EA")
const HP_COLOR: Color = Color("#E74C3C")
const XP_COLOR: Color = Color("#7ED957")
const BAR_BG_COLOR: Color = Color("#0F0F16")
const CORNER_RADIUS: int = 12
const PANEL_PADDING: int = 14
const BAR_RADIUS: int = 8
const TEXT_OUTLINE: int = 6
const BORDER_WIDTH: int = 3
const BUTTON_COLOR: Color = Color("#2E2E3D")
const BUTTON_FOCUS_COLOR: Color = Color("#4A90E2")
const SPARK_COLOR: Color = Color("#FFD43B")
## Tier-Farben I-IV (GDD 12) und an fünfter Stelle Gold für "Einzigartig" (ItemData.UNIQUE_TIER).
const TIER_COLORS: Array[Color] = [Color("#8A8A8A"), Color("#4A90E2"), Color("#9B59B6"), Color("#E74C3C"), Color("#F5A623")]
## Einzigartige Angebotskarten: Hintergrund leicht in Gold getönt.
const UNIQUE_CARD_TINT: float = 0.14


static func tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier, 1, TIER_COLORS.size()) - 1]


static func panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_content_margin_all(PANEL_PADDING)
	return style


static func make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	return panel


static func make_label(font_size: int, color: Color = TEXT_COLOR) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	return label


static func make_bar(fill: Color, size: Vector2) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = BAR_BG_COLOR
	bg.set_corner_radius_all(BAR_RADIUS)
	bg.border_color = OUTLINE_COLOR
	bg.set_border_width_all(BORDER_WIDTH)
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(BAR_RADIUS)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


static func make_button(text: String, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = panel_style()
		style.bg_color = BUTTON_FOCUS_COLOR if state in ["hover", "focus"] else BUTTON_COLOR
		style.border_color = OUTLINE_COLOR
		style.set_border_width_all(BORDER_WIDTH)
		button.add_theme_stylebox_override(state, style)
	return button
