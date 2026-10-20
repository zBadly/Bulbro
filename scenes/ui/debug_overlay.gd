extends CanvasLayer
## Debug-Overlay (F3): zeigt HP, alle Stats und abgeleitete Werte des Spielers live.

const FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const FONT_SIZE: int = 18
const PANEL_COLOR: Color = Color("#1B1B24D9")
const PANEL_RADIUS: int = 12
const PANEL_PADDING: int = 14
const SCREEN_MARGIN: float = 16.0
const REFRESH_INTERVAL: float = 0.2
const PERCENT: float = 100.0

var _label: Label
var _refresh_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(PANEL_RADIUS)
	style.set_content_margin_all(PANEL_PADDING)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2.ONE * SCREEN_MARGIN
	_label = Label.new()
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	panel.add_child(_label)
	add_child(panel)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		visible = not visible
		_refresh()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_INTERVAL
		_refresh()


func _refresh() -> void:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		_label.text = tr("DEBUG_TITLE")
		return
	var s: StatSystem = player.stats
	var lines: PackedStringArray = [tr("DEBUG_TITLE"), ""]
	lines.append("%s: %.1f / %.0f" % [tr("DEBUG_HP"), player.current_hp, player.get_max_hp()])
	lines.append("")
	lines.append("— %s —" % tr("DEBUG_DERIVED"))
	lines.append("%s: %.2f" % [tr("DEBUG_REGEN_PER_SEC"), CombatMath.hp_regen_per_second(s.get_stat(Stats.HP_REGEN))])
	lines.append("%s: %.0f %%" % [tr("DEBUG_DODGE_CHANCE"), CombatMath.dodge_chance(s.get_stat(Stats.DODGE), player.config.dodge_cap) * PERCENT])
	lines.append("%s: %.0f %%" % [tr("DEBUG_ARMOR_REDUCTION"), (1.0 - CombatMath.armor_multiplier(s.get_stat(Stats.ARMOR))) * PERCENT])
	lines.append("%s: %.0f" % [tr("DEBUG_MOVE_SPEED"), player.get_move_speed()])
	lines.append("")
	lines.append("— %s —" % tr("DEBUG_PRIMARY"))
	for stat: StringName in Stats.PRIMARY:
		lines.append("%s: %s" % [tr(Stats.label_key(stat)), _format(s.get_stat(stat))])
	lines.append("")
	lines.append("— %s —" % tr("DEBUG_SECONDARY"))
	for stat: StringName in Stats.SECONDARY:
		var value: float = s.get_stat(stat)
		if not is_zero_approx(value):
			lines.append("%s: %s" % [tr(Stats.label_key(stat)), _format(value)])
	_label.text = "\n".join(lines)


func _format(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value
