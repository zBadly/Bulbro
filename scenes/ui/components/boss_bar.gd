class_name BossBar
extends VBoxContainer
## HP-Leiste eines Elites oder Bosses (Phase 15, Paket 7): Kopfzeile mit Name, "Phase 2/3: Raserei" und bei
## Zeitwechseln Uhr-Symbol mit Restzeit; Balken mit Markierungen an den HP-Schwellen der Phasenwechsel.

const PHASES: BossPhaseConfig = preload("res://data/config/boss_phase_config.tres")
const CLOCK_ICON: Texture2D = preload("res://art/ui/clock.svg")
const NAME_COLOR: Color = Color("#9B59B6")
const HEADER_GAP: int = 8

var enemy: Enemy

var _behavior: PhasedBehavior
var _name_label: Label
var _phase_label: Label
var _clock: TextureRect
var _timer_label: Label
var _bar: ProgressBar
var _markers: Control
var _compact: bool = false
var _shown_phase: int = -1
var _flash_tween: Tween


func setup(p_enemy: Enemy) -> void:
	enemy = p_enemy
	_behavior = enemy.phased_behavior()
	add_theme_constant_override("separation", 0)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", HEADER_GAP)
	add_child(header)
	_name_label = UiStyle.make_label(PHASES.name_size, NAME_COLOR)
	_name_label.text = tr(enemy.data.name_key)
	header.add_child(_name_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_phase_label = UiStyle.make_label(PHASES.name_size)
	header.add_child(_phase_label)
	_clock = TextureRect.new()
	_clock.texture = CLOCK_ICON
	_clock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_clock)
	_timer_label = UiStyle.make_label(PHASES.name_size)
	header.add_child(_timer_label)
	_bar = UiStyle.make_bar(UiStyle.HP_COLOR, PHASES.bar_size)
	_bar.max_value = 1.0
	_bar.value = 1.0
	add_child(_bar)
	_markers = Control.new()
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_draw_markers)
	_bar.add_child(_markers)
	_apply_size()
	refresh()


## Kompakt ab zwei Leisten gleichzeitig (z. B. Doppelboss), damit beide auch in 1280x720 Platz haben.
func set_compact(value: bool) -> void:
	if value != _compact:
		_compact = value
		_apply_size()


func is_compact() -> bool:
	return _compact


## Anzahl der Markierungen (eine je HP-Schwelle).
func marker_count() -> int:
	return _marker_ratios().size()


func phase_text() -> String:
	return _phase_label.text


func timer_text() -> String:
	return _timer_label.text if _timer_label.visible else ""


func refresh() -> void:
	_bar.value = enemy.hp / enemy.max_hp if enemy.max_hp > 0.0 else 0.0
	if _behavior == null:
		_phase_label.hide()
		_clock.hide()
		_timer_label.hide()
		return
	var index: int = _behavior.phase_index
	if index != _shown_phase:
		_shown_phase = index
		var phase: BossPhaseData = _behavior.current_phase()
		_phase_label.text = tr("HUD_BOSS_PHASE") % [index + 1, _behavior.phase_count(), tr(phase.name_key)]
		_phase_label.add_theme_color_override("font_color", phase.aura_color if phase.aura_color.a > 0.0 else UiStyle.TEXT_COLOR)
		_markers.queue_redraw()
	var left: float = _behavior.time_to_next()
	_clock.visible = left >= 0.0
	_timer_label.visible = left >= 0.0
	if left >= 0.0:
		_timer_label.text = tr("HUD_PHASE_TIMER") % ceili(left)


## Kurzes Aufhellen beim Phasenwechsel.
func flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_bar.modulate = Color.WHITE * PHASES.bar_flash_brightness
	_flash_tween = create_tween()
	_flash_tween.tween_property(_bar, "modulate", Color.WHITE, PHASES.bar_flash_time)


func _apply_size() -> void:
	var font_size: int = PHASES.compact_name_size if _compact else PHASES.name_size
	_bar.custom_minimum_size = PHASES.compact_bar_size if _compact else PHASES.bar_size
	for label: Label in [_name_label, _phase_label, _timer_label]:
		label.add_theme_font_size_override("font_size", font_size)
	_clock.custom_minimum_size = Vector2.ONE * font_size * PHASES.clock_scale
	_markers.queue_redraw()


## HP-Anteile der Schwellen; Index = Phase, die an dieser Schwelle endet.
func _marker_ratios() -> Dictionary[int, float]:
	var result: Dictionary[int, float] = {}
	if _behavior == null:
		return result
	var thresholds: Array[float] = _behavior.hp_thresholds()
	for index: int in thresholds.size():
		if thresholds[index] > 0.0:
			result[index] = thresholds[index]
	return result


func _draw_markers() -> void:
	var ratios: Dictionary[int, float] = _marker_ratios()
	var height: float = _markers.size.y
	for index: int in ratios:
		var x: float = _markers.size.x * ratios[index]
		var passed: bool = _behavior.phase_index > index
		var color: Color = PHASES.marker_passed_color if passed else PHASES.marker_color
		var rect: Rect2 = Rect2(x - PHASES.marker_width * 0.5, -PHASES.marker_overhang, PHASES.marker_width, height + PHASES.marker_overhang * 2.0)
		_markers.draw_rect(rect.grow(UiStyle.BORDER_WIDTH * 0.5), Color(UiStyle.OUTLINE_COLOR, color.a))
		_markers.draw_rect(rect, color)
