class_name Hud
extends CanvasLayer
## HUD: HP- und XP-Balken oben links, Wellennummer und Countdown oben Mitte.

const SCREEN_MARGIN: float = 20.0
const BAR_SIZE: Vector2 = Vector2(320, 30)
const BAR_TEXT_SIZE: int = 20
const WAVE_TEXT_SIZE: int = 40
const TIMER_TEXT_SIZE: int = 56
const BANNER_TEXT_SIZE: int = 64
const ROW_GAP: int = 8

var _hp_bar: ProgressBar
var _hp_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _wave_label: Label
var _timer_label: Label
var _banner: Label
var _wave_manager: WaveManager


func _ready() -> void:
	var left: VBoxContainer = VBoxContainer.new()
	left.position = Vector2.ONE * SCREEN_MARGIN
	left.add_theme_constant_override("separation", ROW_GAP)
	add_child(left)
	_hp_bar = UiStyle.make_bar(UiStyle.HP_COLOR, BAR_SIZE)
	_hp_label = _bar_label(_hp_bar)
	left.add_child(_hp_bar)
	_xp_bar = UiStyle.make_bar(UiStyle.XP_COLOR, BAR_SIZE)
	_xp_label = _bar_label(_xp_bar)
	left.add_child(_xp_bar)

	var top: VBoxContainer = VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.position.y = SCREEN_MARGIN
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(top)
	_wave_label = UiStyle.make_label(WAVE_TEXT_SIZE)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_wave_label)
	_timer_label = UiStyle.make_label(TIMER_TEXT_SIZE)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_timer_label)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_banner = UiStyle.make_label(BANNER_TEXT_SIZE)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.hide()
	add_child(_banner)

	set_xp(0.0, 1.0, 0)


func bind(player: Player, wave_manager: WaveManager) -> void:
	_wave_manager = wave_manager
	player.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(player.current_hp, player.get_max_hp())
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_ended.connect(_on_wave_ended)


func set_xp(current: float, needed: float, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = current
	_xp_label.text = tr("HUD_LEVEL") % level


func _process(_delta: float) -> void:
	if _wave_manager != null and _wave_manager.state == WaveManager.State.WAVE:
		_timer_label.text = str(ceili(_wave_manager.time_left))


func _bar_label(bar: ProgressBar) -> Label:
	var label: Label = UiStyle.make_label(BAR_TEXT_SIZE)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)
	return label


func _on_hp_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "%d / %d" % [ceili(current), roundi(maximum)]


func _on_wave_started(number: int) -> void:
	_wave_label.text = tr("HUD_WAVE") % number
	_banner.hide()


func _on_wave_ended(number: int) -> void:
	_timer_label.text = ""
	_banner.text = tr("WAVE_CLEARED") % number
	_banner.show()
