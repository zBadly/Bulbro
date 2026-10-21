class_name StatTable
extends PanelContainer
## Tabelle für Werte (Waffen-Tiers, Gegnerwerte, Set-Boni). Erste Zeile = Kopf, erste Spalte = Zeilenname.
## Zellen sind BBCode, damit Werte grün/rot eingefärbt werden können.

const TEXT_SIZE: int = 19
const H_GAP: int = 22
const V_GAP: int = 4
const PADDING: int = 10
const BG_COLOR: Color = Color("#10101AB3")
const HEADER_COLOR: String = "#FFD43B"
const LABEL_COLOR: String = "#C9C3D6"

var _grid: GridContainer


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.set_corner_radius_all(UiStyle.BAR_RADIUS)
	style.set_content_margin_all(PADDING)
	add_theme_stylebox_override("panel", style)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", H_GAP)
	_grid.add_theme_constant_override("v_separation", V_GAP)
	add_child(_grid)


func set_rows(rows: Array[PackedStringArray]) -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_grid.columns = rows[0].size() if not rows.is_empty() else 1
	for row_index: int in rows.size():
		var row: PackedStringArray = rows[row_index]
		for column: int in _grid.columns:
			var text: String = row[column] if column < row.size() else ""
			if row_index == 0:
				text = "[color=%s]%s[/color]" % [HEADER_COLOR, text]
			elif column == 0:
				text = "[color=%s]%s[/color]" % [LABEL_COLOR, text]
			_grid.add_child(_cell(text))


func get_cell_count() -> int:
	return _grid.get_child_count()


func _cell(bbcode: String) -> RichTextLabel:
	var cell: RichTextLabel = RichTextLabel.new()
	cell.bbcode_enabled = true
	cell.fit_content = true
	cell.scroll_active = false
	cell.autowrap_mode = TextServer.AUTOWRAP_OFF
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.add_theme_font_override("normal_font", UiStyle.FONT)
	cell.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	cell.text = bbcode
	return cell
