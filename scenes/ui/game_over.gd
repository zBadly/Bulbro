class_name GameOverScreen
extends CanvasLayer
## Run-Ende (Sieg oder Niederlage): erreichte Welle, Build-Übersicht, neu freigeschaltete Charaktere.

const RUN_SETUP_SCENE: String = "res://scenes/ui/run_setup.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const DIM_COLOR: Color = Color("#0B0B12D9")
const TITLE_SIZE: int = 96
const TEXT_SIZE: int = 30
const SMALL_SIZE: int = 22
const BUTTON_SIZE: int = 30
const ICON_SIZE: Vector2 = Vector2(56, 56)
const PORTRAIT_SIZE: Vector2 = Vector2(96, 128)
const ICON_BORDER: int = 3
const GAP: int = 18
const MAX_FLOW_WIDTH: float = 900.0
const VICTORY_COLOR: Color = Color("#FFE066")
const UNLOCK_COLOR: Color = Color("#7ED957")

var _box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func show_result(victory: bool, wave_number: int, player: Player) -> void:
	var unlocked: Array[ChallengeData] = Unlocks.evaluate_run_end(victory)
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", GAP)
	center.add_child(_box)

	_label(tr("VICTORY") if victory else tr("GAME_OVER"), TITLE_SIZE, VICTORY_COLOR if victory else UiStyle.HP_COLOR)
	var header: HBoxContainer = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", GAP)
	_box.add_child(header)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = GameState.character.texture
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(portrait)
	var info: VBoxContainer = VBoxContainer.new()
	header.add_child(info)
	var who: Label = UiStyle.make_label(TEXT_SIZE)
	who.text = tr("RUN_END_CHARACTER") % [tr(GameState.character.name_key), tr(GameState.difficulty.name_key)]
	info.add_child(who)
	var reached: Label = UiStyle.make_label(TEXT_SIZE)
	reached.text = tr("REACHED_WAVE") % wave_number
	info.add_child(reached)
	var stats: Label = UiStyle.make_label(SMALL_SIZE)
	stats.text = tr("RUN_END_STATS") % [GameState.level, GameState.total_sparks_collected, GameState.run_stats.enemies_killed]
	info.add_child(stats)

	_label(tr("RUN_END_WEAPONS"), SMALL_SIZE)
	var weapons: HFlowContainer = _flow()
	for weapon: Weapon in player.weapon_slots.get_weapons():
		weapons.add_child(_icon(weapon.data.texture, UiStyle.tier_color(weapon.tier), tr(weapon.data.name_key)))
	_label(tr("RUN_END_ITEMS"), SMALL_SIZE)
	var items: HFlowContainer = _flow()
	var counts: Dictionary[StringName, int] = GameState.item_counts()
	var shown: Dictionary[StringName, bool] = {}
	for item: ItemData in GameState.items:
		if shown.has(item.id):
			continue
		shown[item.id] = true
		var icon: PanelContainer = _icon(item.icon, UiStyle.tier_color(item.tier), tr(item.name_key))
		if counts[item.id] > 1:
			var count: Label = UiStyle.make_label(SMALL_SIZE)
			count.text = "x%d" % counts[item.id]
			icon.add_child(count)
			count.size_flags_horizontal = Control.SIZE_SHRINK_END
			count.size_flags_vertical = Control.SIZE_SHRINK_END
		items.add_child(icon)

	for challenge: ChallengeData in unlocked:
		_label(tr("RUN_END_UNLOCKED") % challenge.reward_name(), TEXT_SIZE, UNLOCK_COLOR)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", GAP)
	_box.add_child(buttons)
	var retry: Button = _button(buttons, tr("RUN_END_RETRY"), _restart)
	_button(buttons, tr("RUN_END_NEW_RUN"), _change_scene.bind(RUN_SETUP_SCENE))
	_button(buttons, tr("RUN_END_MAIN_MENU"), _change_scene.bind(MAIN_MENU_SCENE))
	show()
	get_tree().paused = true
	retry.grab_focus()


func _label(text: String, size: int, color: Color = UiStyle.TEXT_COLOR) -> void:
	var label: Label = UiStyle.make_label(size, color)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(label)


func _flow() -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.custom_minimum_size = Vector2(MAX_FLOW_WIDTH, 0.0)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_box.add_child(flow)
	return flow


func _icon(texture: Texture2D, border: Color, tooltip: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.panel_style()
	style.border_color = border
	style.set_border_width_all(ICON_BORDER)
	panel.add_theme_stylebox_override("panel", style)
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = tooltip
	panel.add_child(icon)
	return panel


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = UiStyle.make_button(text, BUTTON_SIZE)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
