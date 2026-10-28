class_name StatPanel
extends PanelContainer
## Zeigt alle Primär-Stats und alle Sekundär-Stats ungleich 0. Positive Werte grün, negative rot, 0 neutral;
## Stats mit Obergrenze zeigen sie dahinter ("Ausweichen: 45 % (max. 60 %)"), eine erreichte Grenze ist gelb.
## Mit Vorschau-Modifikatoren wird "vorher -> nachher" für jeden betroffenen Stat grün oder rot angezeigt.
## Jede Zeile hat einen Tooltip mit der Erklärung aus dem Lexikon (bei Obergrenze auch deren Bedeutung).

const PLAYER: PlayerConfig = preload("res://data/config/player_config.tres")
const PANEL_WIDTH: float = 360.0
const TITLE_SIZE: int = 28
const TEXT_SIZE: int = 19
const ARROW: String = " » "
const SECTION_GAP: float = 10.0

var _stats: StatSystem
var _title: Label
## Eine Zeile pro Stat; Sekundär-Stats mit Wert 0 sind ausgeblendet.
var _rows: Dictionary[StringName, RichTextLabel] = {}


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_theme_stylebox_override("panel", UiStyle.panel_style())
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	_title = UiStyle.make_label(TITLE_SIZE)
	box.add_child(_title)
	for stat: StringName in Stats.PRIMARY:
		box.add_child(_make_row(stat))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, SECTION_GAP)
	box.add_child(gap)
	for stat: StringName in Stats.SECONDARY:
		box.add_child(_make_row(stat))


func setup(stats: StatSystem) -> void:
	_stats = stats
	refresh()


static func cap_of(stat: StringName) -> float:
	return CombatMath.stat_cap(stat, PLAYER.dodge_cap)


func refresh(preview: Array[StatModifier] = []) -> void:
	_title.text = tr("STATS_TITLE")
	var affected: Array[StringName] = []
	for mod: StatModifier in preview:
		affected.append(mod.stat)
	for stat: StringName in Stats.PRIMARY:
		_rows[stat].text = line(stat, preview, stat in affected)
	for stat: StringName in Stats.SECONDARY:
		var row: RichTextLabel = _rows[stat]
		row.visible = stat in affected or not is_zero_approx(_stats.get_stat(stat))
		if row.visible:
			row.text = line(stat, preview, stat in affected)


## Text einer Zeile (BBCode).
func line(stat: StringName, preview: Array[StatModifier] = [], is_affected: bool = false) -> String:
	var before: float = _stats.get_stat(stat)
	var cap: float = cap_of(stat)
	var text: String = "%s: %s" % [tr(Stats.label_key(stat)), TooltipText.stat_value(stat, before, cap)]
	if is_affected:
		var after: float = _stats.get_stat_with(stat, preview)
		text += ARROW + TextFormat.colored(TextFormat.stat_value(stat, after), TextFormat.is_good(stat, after - before))
	return text


func get_row(stat: StringName) -> RichTextLabel:
	return _rows[stat]


func _make_row(stat: StringName) -> RichTextLabel:
	var row: RichTextLabel = RichTextLabel.new()
	row.bbcode_enabled = true
	row.fit_content = true
	row.scroll_active = false
	row.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_theme_font_override("normal_font", UiStyle.FONT)
	row.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	# Nur Maus: per Gamepad würde der Fokus sonst durch rund 30 Zeilen wandern.
	GameTooltip.attach(row, TooltipText.stat.bind(stat, cap_of(stat)), true, false)
	_rows[stat] = row
	return row
