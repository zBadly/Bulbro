class_name StatPanel
extends PanelContainer
## Zeigt alle Primär-Stats und alle Sekundär-Stats ungleich 0. Mit Vorschau-Modifikatoren wird
## "vorher -> nachher" für jeden betroffenen Stat grün oder rot angezeigt.

const PANEL_WIDTH: float = 360.0
const TITLE_SIZE: int = 28
const TEXT_SIZE: int = 19
const ARROW: String = " → "

var _stats: StatSystem
var _title: Label
var _text: RichTextLabel


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_theme_stylebox_override("panel", UiStyle.panel_style())
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	_title = UiStyle.make_label(TITLE_SIZE)
	box.add_child(_title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_override("normal_font", UiStyle.FONT)
	_text.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	box.add_child(_text)


func setup(stats: StatSystem) -> void:
	_stats = stats
	refresh()


func refresh(preview: Array[StatModifier] = []) -> void:
	_title.text = tr("STATS_TITLE")
	var affected: Array[StringName] = []
	for mod: StatModifier in preview:
		affected.append(mod.stat)
	var lines: PackedStringArray = []
	for stat: StringName in Stats.PRIMARY:
		lines.append(_line(stat, preview, stat in affected))
	lines.append("")
	for stat: StringName in Stats.SECONDARY:
		if stat in affected or not is_zero_approx(_stats.get_stat(stat)):
			lines.append(_line(stat, preview, stat in affected))
	_text.text = "\n".join(lines)


func _line(stat: StringName, preview: Array[StatModifier], is_affected: bool) -> String:
	var before: float = _stats.get_stat(stat)
	var text: String = "%s: %s" % [tr(Stats.label_key(stat)), TextFormat.stat_value(stat, before)]
	if is_affected:
		var after: float = _stats.get_stat_with(stat, preview)
		text += ARROW + TextFormat.colored(TextFormat.stat_value(stat, after), TextFormat.is_good(stat, after - before))
	return text
