class_name AchievementList
extends VBoxContainer
## Achievement-Übersicht (Statistik-Bildschirm): Filter nach Kategorie (mit Zähler je Kategorie) und eine
## Liste mit Icon im Rahmen der Schwierigkeit, Name, Bedingung und Fortschritt ("312/500") bzw. Datum des Erreichens.

const TEXT_SIZE: int = 22
const NAME_SIZE: int = 26
const SMALL_SIZE: int = 18
const ICON_SIZE: Vector2 = Vector2(64, 64)
const FRAME_WIDTH: int = 4
const ROW_GAP: int = 8
const GAP: int = 16
const FILTER_WIDTH: float = 340.0
const ROW_HEIGHT: float = 52.0
const PROGRESS_SIZE: Vector2 = Vector2(280, 22)
const PROGRESS_COLUMN: float = 300.0
const OPEN_ICON_COLOR: Color = Color(0.45, 0.45, 0.5, 1.0)
const DONE_COLOR: Color = Color("#7ED957")
const MUTED_COLOR: Color = Color("#C9C3D6")

var _filter: OptionButton
var _scroll: ScrollContainer
var _rows: VBoxContainer
## Gewählte Kategorie (-1 = alle).
var _category: int = -1


func _init() -> void:
	add_theme_constant_override("separation", GAP)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", GAP)
	add_child(top)
	var label: Label = UiStyle.make_label(TEXT_SIZE)
	label.text = tr("LEX_FILTER_CATEGORY")
	top.add_child(label)
	_filter = OptionButton.new()
	_filter.custom_minimum_size = Vector2(FILTER_WIDTH, ROW_HEIGHT)
	_filter.add_theme_font_override("font", UiStyle.FONT)
	_filter.add_theme_font_size_override("font_size", TEXT_SIZE)
	_filter.get_popup().add_theme_font_override("font", UiStyle.FONT)
	_filter.get_popup().add_theme_font_size_override("font_size", TEXT_SIZE)
	for state: String in ["normal", "hover", "focus", "pressed"]:
		_filter.add_theme_stylebox_override(state, UiStyle.field_style(state != "normal"))
	_filter.item_selected.connect(func(index: int) -> void: set_category(index - 1))
	top.add_child(_filter)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", ROW_GAP)
	_scroll.add_child(_rows)


func _ready() -> void:
	refresh()


## Filter und Liste neu aufbauen (Zähler je Kategorie im Filter).
func refresh() -> void:
	var all: Array[AchievementData] = Unlocks.all_achievements()
	_filter.clear()
	_filter.add_item(tr("ACH_FILTER_ENTRY") % [tr("LEX_FILTER_ALL"), Unlocks.count_completed(all), all.size()])
	for category: int in AchievementData.Category.size():
		var in_category: Array[AchievementData] = all.filter(func(a: AchievementData) -> bool: return a.category == category)
		_filter.add_item(tr("ACH_FILTER_ENTRY") % [tr(AchievementData.CATEGORY_KEY % category), Unlocks.count_completed(in_category), in_category.size()])
	_filter.select(_category + 1)
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for achievement: AchievementData in visible_achievements():
		_rows.add_child(_make_row(achievement))


func set_category(category: int) -> void:
	_category = category
	refresh()


func visible_achievements() -> Array[AchievementData]:
	return Unlocks.all_achievements().filter(func(a: AchievementData) -> bool: return _category < 0 or a.category == _category)


func row_count() -> int:
	return _rows.get_child_count()


func get_scroll() -> ScrollContainer:
	return _scroll


func get_filter() -> OptionButton:
	return _filter


func _make_row(achievement: AchievementData) -> PanelContainer:
	var done: bool = SaveManager.is_challenge_completed(achievement.id)
	var panel: PanelContainer = UiStyle.make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	panel.add_child(row)

	var frame: PanelContainer = PanelContainer.new()
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = UiStyle.BAR_BG_COLOR
	frame_style.border_color = achievement.difficulty_color() if done else OPEN_ICON_COLOR
	frame_style.set_border_width_all(FRAME_WIDTH)
	frame_style.set_corner_radius_all(UiStyle.CORNER_RADIUS)
	frame_style.set_content_margin_all(FRAME_WIDTH)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	var icon: TextureRect = TextureRect.new()
	icon.texture = achievement.icon
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color.WHITE if done else OPEN_ICON_COLOR
	frame.add_child(icon)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var name_label: Label = UiStyle.make_label(NAME_SIZE, UiStyle.TEXT_COLOR if done else MUTED_COLOR)
	name_label.text = achievement.display_name()
	texts.add_child(name_label)
	var description: Label = UiStyle.make_label(TEXT_SIZE, MUTED_COLOR)
	description.text = achievement.condition_text()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(description)
	var meta: Label = UiStyle.make_label(SMALL_SIZE, achievement.difficulty_color())
	meta.text = tr("ACH_META") % [achievement.category_name(), achievement.difficulty_name()]
	texts.add_child(meta)

	var status: VBoxContainer = VBoxContainer.new()
	status.custom_minimum_size = Vector2(PROGRESS_COLUMN, 0.0)
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(status)
	var status_label: Label = UiStyle.make_label(TEXT_SIZE, DONE_COLOR if done else UiStyle.TEXT_COLOR)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(status_label)
	if done:
		var date: int = SaveManager.get_completed_date(achievement.id)
		status_label.text = tr("ACH_DONE_ON") % MetaStats.format_date(date) if date > 0 else tr("ACH_DONE")
	else:
		var progress: float = Unlocks.progress(achievement)
		status_label.text = achievement.progress_text(progress) if achievement.has_progress() else tr("ACH_OPEN")
		if achievement.has_progress():
			var bar: ProgressBar = UiStyle.make_bar(UiStyle.XP_COLOR, PROGRESS_SIZE)
			bar.max_value = achievement.value
			bar.value = minf(progress, achievement.value)
			bar.size_flags_horizontal = Control.SIZE_SHRINK_END
			status.add_child(bar)
	return panel
