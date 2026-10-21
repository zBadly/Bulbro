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
const SPARK_ICON: Texture2D = preload("res://art/pickups/spark.svg")
const SPARK_TEXT_SIZE: int = 30
const BAG_TEXT_SIZE: int = 20
const BAG_COLOR: Color = Color("#FFD43B")
const BOSS_BAR_SIZE: Vector2 = Vector2(720, 26)
const BOSS_NAME_SIZE: int = 24
const BOSS_COLOR: Color = Color("#9B59B6")

var _hp_bar: ProgressBar
var _hp_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _wave_label: Label
var _timer_label: Label
var _banner: Label
var _spark_label: Label
var _bag_label: Label
var _wave_manager: WaveManager
var _boss_box: VBoxContainer
## Elite/Boss -> eigener HP-Balken.
var _boss_bars: Dictionary[Enemy, ProgressBar] = {}


func _ready() -> void:
	# Läuft auch pausiert, damit z. B. der Balken eines besiegten Bosses hinter dem Siegbildschirm verschwindet.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var spark_row: HBoxContainer = HBoxContainer.new()
	spark_row.add_theme_constant_override("separation", ROW_GAP)
	left.add_child(spark_row)
	var icon: TextureRect = TextureRect.new()
	icon.texture = SPARK_ICON
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	spark_row.add_child(icon)
	_spark_label = UiStyle.make_label(SPARK_TEXT_SIZE)
	spark_row.add_child(_spark_label)
	_bag_label = UiStyle.make_label(BAG_TEXT_SIZE, BAG_COLOR)
	_bag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spark_row.add_child(_bag_label)

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
	_boss_box = VBoxContainer.new()
	_boss_box.add_theme_constant_override("separation", ROW_GAP)
	top.add_child(_boss_box)

	_banner = UiStyle.make_label(BANNER_TEXT_SIZE)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.hide()
	add_child(_banner)

	Events.sparks_changed.connect(_on_sparks_changed)
	Events.xp_changed.connect(set_xp)
	Events.run_phase_changed.connect(_on_phase_changed)
	Events.boss_spawned.connect(_on_boss_spawned)
	_on_sparks_changed(GameState.sparks, GameState.bag)
	set_xp(GameState.xp, GameState.xp_needed(), GameState.level)


func bind(player: Player, wave_manager: WaveManager) -> void:
	_wave_manager = wave_manager
	player.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(player.current_hp, player.get_max_hp())
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_ended.connect(_on_wave_ended)


func set_xp(current: float, needed: float, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = current
	if GameState.pending_level_ups > 0:
		_xp_label.text = tr("HUD_LEVEL_PENDING") % [level, GameState.pending_level_ups]
	else:
		_xp_label.text = tr("HUD_LEVEL") % level


func _process(_delta: float) -> void:
	if _wave_manager != null and _wave_manager.state == WaveManager.State.WAVE:
		_timer_label.text = str(ceili(_wave_manager.time_left))
	_update_boss_bars()


func _on_boss_spawned(enemy: Enemy) -> void:
	var name_label: Label = UiStyle.make_label(BOSS_NAME_SIZE, BOSS_COLOR)
	name_label.text = tr(enemy.data.name_key)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(name_label)
	var bar: ProgressBar = UiStyle.make_bar(UiStyle.HP_COLOR, BOSS_BAR_SIZE)
	bar.max_value = 1.0
	bar.value = 1.0
	bar.set_meta(&"label", name_label)
	_boss_box.add_child(bar)
	_boss_bars[enemy] = bar


func _update_boss_bars() -> void:
	for enemy: Enemy in _boss_bars.keys():
		var bar: ProgressBar = _boss_bars[enemy]
		if not is_instance_valid(enemy) or not enemy.is_alive():
			(bar.get_meta(&"label") as Label).queue_free()
			bar.queue_free()
			_boss_bars.erase(enemy)
		else:
			bar.value = enemy.hp / enemy.max_hp


func _bar_label(bar: ProgressBar) -> Label:
	var label: Label = UiStyle.make_label(BAR_TEXT_SIZE)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)
	return label


func _on_sparks_changed(sparks: int, bag: int) -> void:
	_spark_label.text = str(sparks)
	_bag_label.text = tr("HUD_BAG") % bag if bag > 0 else ""


func _on_hp_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	# Krumme Max-HP (z. B. -25 % Max-HP-Modifikationen) nie als "13 / 12" anzeigen
	var shown_max: int = roundi(maximum)
	_hp_label.text = "%d / %d" % [mini(ceili(current), shown_max), shown_max]


func _on_wave_started(number: int) -> void:
	_wave_label.text = tr("HUD_WAVE_ENDLESS") % number if GameState.endless else tr("HUD_WAVE") % number
	_banner.hide()


func _on_wave_ended(number: int) -> void:
	_timer_label.text = ""
	_banner.text = tr("WAVE_CLEARED") % number
	_banner.show()


## Banner nur zwischen Wellenende und den Karton-/Level-up-/Shop-Bildschirmen zeigen.
func _on_phase_changed(phase: int) -> void:
	if phase != GameState.Phase.POST_WAVE:
		_banner.hide()
