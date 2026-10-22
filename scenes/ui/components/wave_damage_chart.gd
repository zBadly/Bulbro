class_name WaveDamageChart
extends Control
## Balkendiagramm "Schaden pro Welle" am Run-Ende (Phase 15, Paket 5): zeigt, ab wann der Build trägt.
## Endloswellen in eigener Farbe; die Wellennummern werden ausgedünnt, damit sie sich nie überlappen.

const BAR_COLOR: Color = Color("#FFD43B")
const BEST_COLOR: Color = Color("#FFF3B0")
const ENDLESS_COLOR: Color = Color("#9B59B6")
const AXIS_COLOR: Color = Color("#5A5566")
const LABEL_COLOR: Color = Color("#C9C3D6")
const LABEL_SIZE: int = 18
const OUTLINE: int = 4
## Platz für die Wellennummern unten und den Höchstwert oben (px).
const BOTTOM_SPACE: float = 28.0
const TOP_SPACE: float = 28.0
const BAR_GAP_FACTOR: float = 0.25
const MIN_LABEL_SPACING: float = 34.0
const AXIS_WIDTH: float = 2.0

var _values: Array[int] = []
## Index der ersten Endloswelle (-1 = keine).
var _endless_from: int = -1


## `values`: Schaden je Welle ab Welle 1; `endless_from`: Wellennummer der ersten Endloswelle (0 = keine).
func set_data(values: Array[int], endless_from: int) -> void:
	_values = values.duplicate()
	_endless_from = endless_from - 1 if endless_from > 0 else -1
	queue_redraw()


func _draw() -> void:
	var font: Font = UiStyle.FONT
	var plot: Rect2 = Rect2(0.0, TOP_SPACE, size.x, size.y - TOP_SPACE - BOTTOM_SPACE)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, AXIS_COLOR, AXIS_WIDTH)
	if _values.is_empty():
		return
	var highest: int = 0
	var best: int = 0
	for i: int in _values.size():
		if _values[i] > highest:
			highest = _values[i]
			best = i
	_text(font, Vector2(0.0, LABEL_SIZE), TextFormat.t("RUN_STATS_CHART_MAX") % RunReport.format_int(highest), HORIZONTAL_ALIGNMENT_LEFT)
	var slot: float = plot.size.x / _values.size()
	var bar_width: float = maxf(1.0, slot * (1.0 - BAR_GAP_FACTOR))
	var label_step: int = maxi(1, ceili(MIN_LABEL_SPACING / slot))
	for i: int in _values.size():
		var x: float = plot.position.x + slot * i + (slot - bar_width) * 0.5
		var ratio: float = float(_values[i]) / highest if highest > 0 else 0.0
		var height: float = plot.size.y * ratio
		var color: Color = BAR_COLOR
		if _endless_from >= 0 and i >= _endless_from:
			color = ENDLESS_COLOR
		elif i == best and highest > 0:
			color = BEST_COLOR
		if height > 0.0:
			draw_rect(Rect2(x, plot.end.y - height, bar_width, height), color)
		if i % label_step == 0:
			_text(font, Vector2(x + bar_width * 0.5 - MIN_LABEL_SPACING * 0.5, size.y - OUTLINE), str(i + 1),
				HORIZONTAL_ALIGNMENT_CENTER, MIN_LABEL_SPACING)


func _text(font: Font, at: Vector2, text: String, align: HorizontalAlignment, width: float = -1.0) -> void:
	draw_string_outline(font, at, text, align, width, LABEL_SIZE, OUTLINE, UiStyle.OUTLINE_COLOR)
	draw_string(font, at, text, align, width, LABEL_SIZE, LABEL_COLOR)
