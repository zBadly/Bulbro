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
const PHASES: BossPhaseConfig = preload("res://data/config/boss_phase_config.tres")
const HUD_CONFIG: HudConfig = preload("res://data/config/hud_config.tres")
const ADMIN_BADGE_SIZE: int = 20
const ADMIN_BADGE_COLOR: Color = Color("#E74C3C")
## Banner "Bosse besiegt!" im Endlos-Modus: Gold, springt aus dieser Größe auf normal.
const CYCLE_BANNER_COLOR: Color = Color("#F5A623")
const CYCLE_BANNER_POP_SCALE: float = 1.4
const CYCLE_BANNER_POP_TIME: float = 0.25

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
## Elite/Boss -> eigene HP-Leiste mit Phasenanzeige.
var _boss_bars: Dictionary[Enemy, BossBar] = {}
## Phasenwechsel: Gegnername klein, darunter groß "Phase 2: Raserei" (oberhalb der Bildmitte).
var _phase_banner: VBoxContainer
var _phase_banner_name: Label
var _phase_banner_text: Label
var _phase_banner_tween: Tween
## Kleines Abzeichen, sobald im Run eine Admin-Aktion ausgeführt wurde.
var _admin_badge: Label
var _banner_tween: Tween
var _player: Player
## Effekt-Anzeigen (Reservebatterie verfügbar/verbraucht, Ladung des Kondensators): eine pro Trigger mit hud_charge.
var _effect_row: HBoxContainer
var _effect_widgets: Dictionary[TriggerEntry, Control] = {}


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
	_effect_row = HBoxContainer.new()
	_effect_row.add_theme_constant_override("separation", ROW_GAP)
	left.add_child(_effect_row)
	_admin_badge = UiStyle.make_label(ADMIN_BADGE_SIZE, ADMIN_BADGE_COLOR)
	_admin_badge.text = tr("ADMIN_BADGE")
	_admin_badge.hide()
	left.add_child(_admin_badge)

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
	# Sprung-Animation um die Mitte; die Größe folgt dem Text.
	_banner.resized.connect(func() -> void: _banner.pivot_offset = _banner.size / 2.0)
	add_child(_banner)
	_build_phase_banner()

	Events.sparks_changed.connect(_on_sparks_changed)
	Events.xp_changed.connect(set_xp)
	Events.run_phase_changed.connect(_on_phase_changed)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_phase_changed.connect(_on_boss_phase_changed)
	Events.endless_bosses_defeated.connect(_on_endless_bosses_defeated)
	_on_sparks_changed(GameState.sparks, GameState.bag)
	set_xp(GameState.xp, GameState.xp_needed(), GameState.level)


func bind(player: Player, wave_manager: WaveManager) -> void:
	_player = player
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
	_update_effects()
	_admin_badge.visible = GameState.admin.used


## Effekt-Anzeigen abgleichen: neue Trigger bekommen ein Icon, weggefallene verschwinden.
## Füllstand 1 = bereit (Icon voll, Leiste gold), darunter blasser mit Ladeleiste.
func _update_effects() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var seen: Array[TriggerEntry] = []
	for entry: TriggerEntry in _player.triggers:
		var charge: float = entry.effect.hud_charge(entry)
		if charge < 0.0:
			continue
		seen.append(entry)
		if not _effect_widgets.has(entry):
			_effect_widgets[entry] = _make_effect_widget(entry)
		_show_effect_charge(_effect_widgets[entry], charge)
	for entry: TriggerEntry in _effect_widgets.keys():
		if entry not in seen:
			_effect_widgets[entry].queue_free()
			_effect_widgets.erase(entry)


func _make_effect_widget(entry: TriggerEntry) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var icon: TextureRect = TextureRect.new()
	icon.texture = RunReport.source_icon(entry.origin)
	icon.custom_minimum_size = Vector2.ONE * HUD_CONFIG.effect_icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var bar: ProgressBar = UiStyle.make_bar(HUD_CONFIG.effect_charge_color, Vector2(HUD_CONFIG.effect_icon_size, HUD_CONFIG.effect_bar_height))
	bar.max_value = 1.0
	box.add_child(bar)
	box.tooltip_text = RunReport.source_name(entry.origin)
	_effect_row.add_child(box)
	return box


func _show_effect_charge(widget: Control, charge: float) -> void:
	var icon: TextureRect = widget.get_child(0) as TextureRect
	var bar: ProgressBar = widget.get_child(1) as ProgressBar
	icon.modulate.a = lerpf(HUD_CONFIG.effect_used_alpha, 1.0, charge)
	bar.value = charge
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = HUD_CONFIG.effect_ready_color if charge >= 1.0 else HUD_CONFIG.effect_charge_color


func effect_charges() -> Array[float]:
	var result: Array[float] = []
	for widget: Control in _effect_widgets.values():
		result.append((widget.get_child(1) as ProgressBar).value)
	return result


func _on_boss_spawned(enemy: Enemy) -> void:
	var bar: BossBar = BossBar.new()
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_box.add_child(bar)
	bar.setup(enemy)
	_boss_bars[enemy] = bar
	_update_boss_bars()


## Leisten aktualisieren, besiegte entfernen; ab compact_from Leisten kompakt.
func _update_boss_bars() -> void:
	for enemy: Enemy in _boss_bars.keys():
		var bar: BossBar = _boss_bars[enemy]
		if not is_instance_valid(enemy) or not enemy.is_alive():
			bar.queue_free()
			_boss_bars.erase(enemy)
	var compact: bool = _boss_bars.size() >= PHASES.compact_from
	for bar: BossBar in _boss_bars.values():
		bar.set_compact(compact)
		bar.refresh()


func boss_bars() -> Array[BossBar]:
	var result: Array[BossBar] = []
	result.assign(_boss_bars.values())
	return result


func _build_phase_banner() -> void:
	_phase_banner = VBoxContainer.new()
	_phase_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_phase_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_phase_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_phase_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_phase_banner.position.y -= PHASES.banner_offset_y
	_phase_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_banner_name = UiStyle.make_label(PHASES.name_size)
	_phase_banner_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner.add_child(_phase_banner_name)
	_phase_banner_text = UiStyle.make_label(PHASES.boss_banner_size)
	_phase_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner.add_child(_phase_banner_text)
	_phase_banner.resized.connect(func() -> void: _phase_banner.pivot_offset = _phase_banner.size / 2.0)
	_phase_banner.hide()
	add_child(_phase_banner)


## Phasenwechsel: Banner (Elites kleiner und kürzer) in Phasenfarbe, Leiste blitzt auf.
func _on_boss_phase_changed(enemy: Enemy, phase_index: int) -> void:
	if _boss_bars.has(enemy):
		_boss_bars[enemy].refresh()
		_boss_bars[enemy].flash()
	var phase: BossPhaseData = enemy.phased_behavior().current_phase()
	var boss: bool = enemy.data.is_boss
	_phase_banner_name.text = tr(enemy.data.name_key)
	_phase_banner_text.text = tr("PHASE_BANNER") % [phase_index + 1, tr(phase.name_key)]
	_phase_banner_text.add_theme_font_size_override("font_size", PHASES.boss_banner_size if boss else PHASES.elite_banner_size)
	_phase_banner_text.add_theme_color_override("font_color", phase.aura_color if phase.aura_color.a > 0.0 else UiStyle.TEXT_COLOR)
	_phase_banner.reset_size()
	_phase_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_phase_banner.position.y -= PHASES.banner_offset_y
	_phase_banner.show()
	if _phase_banner_tween != null:
		_phase_banner_tween.kill()
	_phase_banner.scale = Vector2.ONE * PHASES.banner_pop_scale
	_phase_banner_tween = create_tween()
	_phase_banner_tween.tween_property(_phase_banner, "scale", Vector2.ONE, PHASES.banner_pop_time) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_phase_banner_tween.tween_interval(maxf(0.0, (PHASES.boss_banner_time if boss else PHASES.elite_banner_time) - PHASES.banner_pop_time))
	_phase_banner_tween.tween_callback(_phase_banner.hide)


func phase_banner_text() -> String:
	return _phase_banner_text.text if _phase_banner.visible else ""


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
	if GameState.endless:
		_wave_label.text = tr("HUD_WAVE_ENDLESS") % [GameState.endless_level(), number]
	else:
		_wave_label.text = tr("HUD_WAVE") % number
	_banner.hide()


func _on_wave_ended(number: int) -> void:
	_timer_label.text = ""
	_show_banner(tr("WAVE_CLEARED") % number, Color.WHITE)


## Endlos-Bosse besiegt: goldenes Banner mit kleinem Sprung, verschwindet nach boss_banner_time.
func _on_endless_bosses_defeated(cycle: int) -> void:
	_show_banner(tr("ENDLESS_BOSSES_DEFEATED") % cycle, CYCLE_BANNER_COLOR)
	_banner.scale = Vector2.ONE * CYCLE_BANNER_POP_SCALE
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, CYCLE_BANNER_POP_TIME) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(maxf(0.0, EndlessRules.CONFIG.boss_banner_time - CYCLE_BANNER_POP_TIME))
	_banner_tween.tween_callback(_banner.hide)


func _show_banner(text: String, color: Color) -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.scale = Vector2.ONE
	_banner.modulate = color
	_banner.text = text
	_banner.show()


## Banner nur zwischen Wellenende und den Karton-/Level-up-/Shop-Bildschirmen zeigen.
func _on_phase_changed(phase: int) -> void:
	if phase != GameState.Phase.POST_WAVE:
		_banner.hide()
