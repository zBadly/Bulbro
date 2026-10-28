class_name RunStatsPanel
extends VBoxContainer
## Reiter "Statistiken" am Run-Ende (Phase 15, Paket 5): Zusammenfassung, Tabelle je Herkunft und Diagramm
## "Schaden pro Welle". Die Tabelle sortiert per Klick auf einen Spaltenkopf (nochmal = Richtung umkehren) oder per
## Taste (R bzw. X am Gamepad, Aktion "stats_sort"). Die Herkunft mit dem meisten Schaden ist als MVP markiert.
## Feste Größen für die Basisauflösung 1920 x 1080; die Tabelle scrollt intern, nichts wird abgeschnitten.

const CAPTION_SIZE: int = 20
const VALUE_SIZE: int = 28
const TEXT_SIZE: int = 22
const HINT_SIZE: int = 18
const SUMMARY_COLUMNS: int = 5
const SUMMARY_CELL_WIDTH: float = 300.0
const GAP: int = 12
const ROW_HEIGHT: float = 44.0
const HEADER_HEIGHT: float = 44.0
const ICON_SIZE: float = 34.0
const ROW_PADDING: int = 8
const CHART_WIDTH: float = 520.0
const CHART_HEIGHT: float = 380.0
const COLUMN_WIDTHS: Dictionary[RunReport.Column, float] = {
	RunReport.Column.NAME: 360.0, RunReport.Column.KIND: 170.0, RunReport.Column.KILLS: 120.0,
	RunReport.Column.DAMAGE: 150.0, RunReport.Column.SHARE: 120.0, RunReport.Column.DPS: 120.0,
}
const COLUMN_KEYS: Dictionary[RunReport.Column, String] = {
	RunReport.Column.NAME: "RUN_STATS_COL_SOURCE", RunReport.Column.KIND: "RUN_STATS_COL_KIND",
	RunReport.Column.KILLS: "RUN_STATS_COL_KILLS", RunReport.Column.DAMAGE: "RUN_STATS_COL_DAMAGE",
	RunReport.Column.SHARE: "RUN_STATS_COL_SHARE", RunReport.Column.DPS: "RUN_STATS_COL_DPS",
}
## Erklärungen im Tooltip des Spaltenkopfs.
const COLUMN_TIPS: Dictionary[RunReport.Column, String] = {
	RunReport.Column.SHARE: "RUN_STATS_SHARE_TIP", RunReport.Column.DPS: "RUN_STATS_DPS_TIP",
}
## Reihenfolge beim Durchschalten per Taste.
const SORT_CYCLE: Array[RunReport.Column] = [
	RunReport.Column.DAMAGE, RunReport.Column.DPS, RunReport.Column.KILLS, RunReport.Column.SHARE,
	RunReport.Column.NAME, RunReport.Column.KIND,
]
## Text-Spalten sortieren zuerst aufsteigend, Zahlen absteigend.
const ASCENDING_FIRST: Array[RunReport.Column] = [RunReport.Column.NAME, RunReport.Column.KIND]
## Sortierpfeile als Icon (die Spielschrift hat keine Pfeil-Glyphen).
const SORT_DOWN: Texture2D = preload("res://art/ui/sort_down.svg")
const SORT_UP: Texture2D = preload("res://art/ui/sort_up.svg")
const CAPTION_COLOR: Color = Color("#C9C3D6")
const MUTED_COLOR: Color = Color("#8A8A8A")
const MVP_COLOR: Color = Color("#FFD43B")
const MVP_ROW_COLOR: Color = Color("#FFD43B2E")
const MVP_TEXT_COLOR: Color = Color("#2A1E2E")
const MVP_SIZE: int = 18
const ROW_COLOR: Color = Color("#FFFFFF0A")
const ROW_ALT_COLOR: Color = Color("#00000000")
const KIND_COLORS: Dictionary[String, Color] = {
	DamageSource.WEAPON: Color("#4A90E2"), DamageSource.ITEM: Color("#7ED957"),
	DamageSource.CHARACTER: Color("#FFB347"), DamageSource.ALLY: Color("#9B59B6"),
	DamageSource.STRUCTURE: Color("#5BC0BE"), DamageSource.PET: Color("#F78FB3"),
}

var rows: Array[RunReport.Row] = []
var sort_column: RunReport.Column = RunReport.Column.DAMAGE
var descending: bool = true
var mvp_origin: StringName = &""
## Zeilen-Buttons in Anzeigereihenfolge (Fokus, Tests).
var row_buttons: Array[Button] = []

var _player: Player
var _header_buttons: Dictionary[RunReport.Column, Button] = {}
var _row_box: VBoxContainer
var _scroll: ScrollContainer
## Platzhalter im Kopf in Breite der Scrollleiste, damit Kopf und Zeilen bündig bleiben.
var _header_spacer: Control


func _init(player: Player) -> void:
	_player = player
	add_theme_constant_override("separation", GAP)
	var run: RunStats = GameState.run_stats
	rows = RunReport.rows(run)
	mvp_origin = RunReport.mvp(rows)
	_build_summary(run)

	var main: HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override("separation", GAP)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main)
	var table_panel: PanelContainer = UiStyle.make_panel()
	table_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(table_panel)
	var table: VBoxContainer = VBoxContainer.new()
	table.add_theme_constant_override("separation", GAP / 2)
	table_panel.add_child(table)
	table.add_child(_build_header())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.add_child(_scroll)
	_row_box = VBoxContainer.new()
	_row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_row_box)
	var hint: Label = UiStyle.make_label(HINT_SIZE, CAPTION_COLOR)
	hint.text = tr("RUN_STATS_SORT_HINT")
	table.add_child(hint)

	var chart_panel: PanelContainer = UiStyle.make_panel()
	main.add_child(chart_panel)
	var chart_box: VBoxContainer = VBoxContainer.new()
	chart_panel.add_child(chart_box)
	var chart_title: Label = UiStyle.make_label(TEXT_SIZE)
	chart_title.text = tr("RUN_STATS_CHART_TITLE")
	chart_box.add_child(chart_title)
	var chart: WaveDamageChart = WaveDamageChart.new()
	chart.custom_minimum_size = Vector2(CHART_WIDTH, CHART_HEIGHT)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.set_data(run.wave_damage, GameState.endless_start_wave + 1 if GameState.endless else 0)
	chart_box.add_child(chart)
	_fill_rows()


func _ready() -> void:
	_header_spacer.custom_minimum_size.x = _scroll.get_v_scroll_bar().get_combined_minimum_size().x


## Spaltenkopf geklickt: gleiche Spalte kehrt die Richtung um, neue Spalte startet mit ihrer Standardrichtung.
func sort_by(column: RunReport.Column) -> void:
	if column == sort_column:
		descending = not descending
	else:
		sort_column = column
		descending = column not in ASCENDING_FIRST
	_fill_rows()


## Taste "stats_sort": nächste Spalte in SORT_CYCLE.
func cycle_sort() -> void:
	var next: RunReport.Column = SORT_CYCLE[(SORT_CYCLE.find(sort_column) + 1) % SORT_CYCLE.size()]
	var had_focus: bool = row_buttons.any(func(b: Button) -> bool: return b.has_focus())
	sort_by(next)
	if had_focus and not row_buttons.is_empty():
		row_buttons[0].grab_focus.call_deferred()


func _build_summary(run: RunStats) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = SUMMARY_COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP / 2)
	var panel: PanelContainer = UiStyle.make_panel()
	panel.add_child(grid)
	add_child(panel)
	var wave_text: String = str(GameState.current_wave)
	if GameState.endless:
		wave_text = tr("RUN_STATS_ENDLESS_WAVE") % [GameState.endless_level(), GameState.current_wave]
	var entries: Array[Array] = [
		["RUN_STATS_TIME", RunReport.format_time(run.combat_time())],
		["RUN_STATS_WAVE", wave_text],
		["RUN_STATS_LEVEL", str(GameState.level)],
		["RUN_STATS_KILLS", RunReport.format_int(run.enemies_killed)],
		["RUN_STATS_SPARKS", tr("RUN_STATS_SPARKS_VALUE") % [
			RunReport.format_int(GameState.total_sparks_collected), RunReport.format_int(run.sparks_spent)]],
		["RUN_STATS_DAMAGE_TAKEN", RunReport.format_int(run.damage_taken)],
		["RUN_STATS_HEALED", RunReport.format_int(roundi(run.healed))],
		["RUN_STATS_DODGES", RunReport.format_int(run.dodges)],
		["RUN_STATS_REROLLS", str(run.rerolls)],
		["RUN_STATS_TOTAL_DAMAGE", RunReport.format_int(run.total_damage())],
	]
	if GameState.endless:
		entries.append(["RUN_STATS_BOSS_CYCLES", str(run.boss_cycles)])
	for entry: Array in entries:
		var cell: VBoxContainer = VBoxContainer.new()
		cell.custom_minimum_size = Vector2(SUMMARY_CELL_WIDTH, 0.0)
		cell.add_theme_constant_override("separation", 0)
		var caption: Label = UiStyle.make_label(CAPTION_SIZE, CAPTION_COLOR)
		caption.text = tr(entry[0])
		cell.add_child(caption)
		var value: Label = UiStyle.make_label(VALUE_SIZE)
		value.text = entry[1]
		cell.add_child(value)
		grid.add_child(cell)


func _build_header() -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	for column: RunReport.Column in COLUMN_WIDTHS:
		var button: Button = UiStyle.make_button("", CAPTION_SIZE)
		button.custom_minimum_size = Vector2(COLUMN_WIDTHS[column], HEADER_HEIGHT)
		if column == RunReport.Column.NAME:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT if column in ASCENDING_FIRST else HORIZONTAL_ALIGNMENT_RIGHT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.pressed.connect(sort_by.bind(column))
		if COLUMN_TIPS.has(column):
			GameTooltip.attach(button, func() -> String: return tr(COLUMN_TIPS[column]))
		header.add_child(button)
		_header_buttons[column] = button
	_header_spacer = Control.new()
	header.add_child(_header_spacer)
	return header


func _update_header() -> void:
	for column: RunReport.Column in _header_buttons:
		var button: Button = _header_buttons[column]
		var active: bool = column == sort_column
		button.text = tr(COLUMN_KEYS[column])
		button.icon = (SORT_DOWN if descending else SORT_UP) if active else null
		var color: Color = MVP_COLOR if active else UiStyle.TEXT_COLOR
		for state: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color"]:
			button.add_theme_color_override(state, color)
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_focus_color", color)


func _fill_rows() -> void:
	RunReport.sort_rows(rows, sort_column, descending)
	_update_header()
	for child: Node in _row_box.get_children():
		_row_box.remove_child(child)
		child.queue_free()
	row_buttons.clear()
	if rows.is_empty():
		var empty: Label = UiStyle.make_label(TEXT_SIZE, MUTED_COLOR)
		empty.text = tr("RUN_STATS_EMPTY")
		_row_box.add_child(empty)
		return
	for i: int in rows.size():
		var button: Button = _make_row(rows[i], i)
		_row_box.add_child(button)
		row_buttons.append(button)


func _make_row(row: RunReport.Row, index: int) -> Button:
	var mvp: bool = row.origin == mvp_origin
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = MVP_ROW_COLOR if mvp else (ROW_COLOR if index % 2 == 0 else ROW_ALT_COLOR)
		style.set_corner_radius_all(UiStyle.BAR_RADIUS)
		if state in ["hover", "focus"]:
			style.border_color = UiStyle.BUTTON_FOCUS_COLOR
			style.set_border_width_all(UiStyle.BORDER_WIDTH)
		button.add_theme_stylebox_override(state, style)
	var cells: HBoxContainer = HBoxContainer.new()
	cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cells.add_theme_constant_override("separation", 0)
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cells)

	var name_cell: HBoxContainer = HBoxContainer.new()
	name_cell.custom_minimum_size = Vector2(COLUMN_WIDTHS[RunReport.Column.NAME], 0.0)
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_cell.add_theme_constant_override("separation", ROW_PADDING)
	name_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cells.add_child(name_cell)
	# Icon beginnt bündig mit dem Text im Spaltenkopf (Innenabstand der Kopf-Buttons).
	var indent: Control = Control.new()
	indent.custom_minimum_size = Vector2(UiStyle.PANEL_PADDING - ROW_PADDING, 0.0)
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_cell.add_child(indent)
	var icon: TextureRect = TextureRect.new()
	icon.texture = RunReport.source_icon(row.origin)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_cell.add_child(icon)
	var name_label: Label = _cell_label(row.name, 0.0, HORIZONTAL_ALIGNMENT_LEFT, MVP_COLOR if mvp else UiStyle.TEXT_COLOR, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_cell.add_child(name_label)
	if mvp:
		name_cell.add_child(_mvp_badge())
		var gap: Control = Control.new()
		gap.custom_minimum_size = Vector2(UiStyle.PANEL_PADDING - ROW_PADDING, 0.0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_cell.add_child(gap)

	cells.add_child(_cell_label(RunReport.kind_name(row.kind), COLUMN_WIDTHS[RunReport.Column.KIND],
		HORIZONTAL_ALIGNMENT_LEFT, KIND_COLORS.get(row.kind, MUTED_COLOR)))
	cells.add_child(_cell_label(RunReport.format_int(row.kills), COLUMN_WIDTHS[RunReport.Column.KILLS]))
	cells.add_child(_cell_label(RunReport.format_int(row.damage), COLUMN_WIDTHS[RunReport.Column.DAMAGE]))
	cells.add_child(_cell_label(RunReport.format_percent(row.share), COLUMN_WIDTHS[RunReport.Column.SHARE]))
	cells.add_child(_cell_label(RunReport.format_dps(row.dps), COLUMN_WIDTHS[RunReport.Column.DPS]))

	var tip: Callable = _row_tooltip(row)
	if tip.is_valid():
		GameTooltip.attach(button, tip)
	return button


## Zelle mit dem Innenabstand der Kopf-Buttons, damit Zahlen und Spaltentitel bündig stehen.
func _cell_label(text: String, width: float, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT,
		color: Color = UiStyle.TEXT_COLOR, padded: bool = true) -> Label:
	var label: Label = UiStyle.make_label(TEXT_SIZE, color)
	label.text = text
	if padded:
		var style: StyleBoxEmpty = StyleBoxEmpty.new()
		style.content_margin_left = UiStyle.PANEL_PADDING
		style.content_margin_right = UiStyle.PANEL_PADDING
		label.add_theme_stylebox_override("normal", style)
	label.custom_minimum_size = Vector2(width, 0.0)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Goldenes Abzeichen "MVP" hinter dem Namen der stärksten Herkunft.
func _mvp_badge() -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = MVP_COLOR
	style.set_corner_radius_all(UiStyle.BAR_RADIUS)
	style.content_margin_left = ROW_PADDING
	style.content_margin_right = ROW_PADDING
	badge.add_theme_stylebox_override("panel", style)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = Label.new()
	label.text = tr("RUN_STATS_MVP")
	label.add_theme_font_override("font", UiStyle.FONT)
	label.add_theme_font_size_override("font_size", MVP_SIZE)
	label.add_theme_color_override("font_color", MVP_TEXT_COLOR)
	badge.add_child(label)
	return badge


## Tooltip einer Zeile: Waffen mit ihren aktuellen Werten, Items mit Effekten; sonst keiner.
func _row_tooltip(row: RunReport.Row) -> Callable:
	var data: Resource = RunReport.source_data(row.origin)
	if data is WeaponData and _player != null:
		for weapon: Weapon in _player.weapon_slots.get_weapons():
			if weapon.data.id == (data as WeaponData).id:
				return TooltipText.weapon.bind(weapon)
	elif data is ItemData:
		var count: int = GameState.item_count((data as ItemData).id)
		if count > 0:
			return TooltipText.item.bind(data, count)
	return Callable()
