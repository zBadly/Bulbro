class_name RunSetup
extends Control
## Vor dem Run: Charakterauswahl (Raster, gesperrte als Silhouette) -> Startwaffe -> Spannung -> Run.

enum Step { CHARACTER, WEAPON, DIFFICULTY }

const RUN_SCENE: String = "res://scenes/world/main.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const DIFFICULTY_PATH: String = "res://data/difficulties/spannung_%d.tres"
const DIFFICULTY_COUNT: int = 6
const FLOOR_TEXTURE: Texture2D = preload("res://art/world/floor_tile.svg")
const DIM_COLOR: Color = Color("#0B0B12B3")
const TITLE_SIZE: int = 52
const TEXT_SIZE: int = 22
const NAME_SIZE: int = 36
const GRID_COLUMNS: int = 6
const PORTRAIT_BUTTON: Vector2 = Vector2(116, 140)
const PORTRAIT_LARGE: Vector2 = Vector2(144, 192)
const DETAIL_WIDTH: float = 520.0
## Sichtbare Rasterzeilen; Raster und Infopanel sind immer so hoch (feste Bereiche, nichts springt beim Auswählen).
## Bei mehr Charakteren scrollt nur das Raster.
const GRID_VISIBLE_ROWS: int = 4
const DIFFICULTY_WIDTH: float = 820.0
const GAP: int = 20
const LOCKED_COLOR: Color = Color("#000000")

var _step: Step = Step.CHARACTER
var _characters: Array[CharacterData] = []
var _character: CharacterData
var _weapon: WeaponData
var _content: VBoxContainer
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _confirm: Button


func _ready() -> void:
	get_tree().paused = false
	_characters = Unlocks.all_characters()
	var last: CharacterData = GameState.character
	_character = last if last != null and Unlocks.is_unlocked(last) else _characters[0]
	var floor_rect: TextureRect = TextureRect.new()
	floor_rect.texture = FLOOR_TEXTURE
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	floor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(floor_rect)
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", GAP)
	center.add_child(_content)
	_show_step(Step.CHARACTER)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _show_step(step: Step) -> void:
	_step = step
	# Sofort aus dem Layout nehmen, sonst wird einen Frame lang alter und neuer Inhalt zusammen zentriert
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match step:
		Step.CHARACTER:
			_build_characters()
		Step.WEAPON:
			_build_weapons()
		Step.DIFFICULTY:
			_build_difficulties()


func _back() -> void:
	match _step:
		Step.CHARACTER:
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		Step.WEAPON:
			_show_step(Step.CHARACTER)
		Step.DIFFICULTY:
			_show_step(Step.WEAPON if _character.starting_weapons.size() > 1 else Step.CHARACTER)


# --- Charakter ---

func _build_characters() -> void:
	_title(tr("SELECT_CHARACTER"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP * 2)
	_content.add_child(row)
	var area_height: float = GRID_VISIBLE_ROWS * PORTRAIT_BUTTON.y + (GRID_VISIBLE_ROWS - 1) * (GAP / 2)
	var grid_scroll: ScrollContainer = ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.custom_minimum_size = Vector2(GRID_COLUMNS * PORTRAIT_BUTTON.x + (GRID_COLUMNS - 1) * (GAP / 2), area_height)
	# Scrollt nur, wenn mehr als GRID_VISIBLE_ROWS Reihen existieren und der Fokus aus dem Bild wandert
	grid_scroll.follow_focus = true
	row.add_child(grid_scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", GAP / 2)
	grid.add_theme_constant_override("v_separation", GAP / 2)
	grid_scroll.add_child(grid)
	var detail_panel: PanelContainer = UiStyle.make_panel()
	detail_panel.custom_minimum_size = Vector2(DETAIL_WIDTH, area_height)
	detail_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(detail_panel)
	# Langer Text scrollt nur innerhalb des Panels
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.follow_focus = false
	detail_panel.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", GAP / 2)
	_detail_scroll.add_child(_detail)

	var selected_button: Button = null
	for character: CharacterData in _characters:
		var button: Button = UiStyle.make_button("", TEXT_SIZE)
		button.icon = character.get_portrait()
		button.expand_icon = true
		button.custom_minimum_size = PORTRAIT_BUTTON
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not Unlocks.is_unlocked(character):
			for state: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color"]:
				button.add_theme_color_override(state, LOCKED_COLOR)
		button.focus_entered.connect(_select_character.bind(character))
		button.mouse_entered.connect(_select_character.bind(character))
		button.pressed.connect(_confirm_character)
		grid.add_child(button)
		if character == _character:
			selected_button = button

	var buttons: HBoxContainer = _button_row()
	_add_button(buttons, tr("BACK"), _back)
	_confirm = _add_button(buttons, tr("CONFIRM"), _confirm_character)
	_select_character(_character)
	selected_button.call_deferred("grab_focus")


func _select_character(character: CharacterData) -> void:
	_character = character
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	_detail_scroll.scroll_vertical = 0
	var unlocked: bool = Unlocks.is_unlocked(character)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = character.get_portrait()
	portrait.custom_minimum_size = PORTRAIT_LARGE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not unlocked:
		portrait.modulate = LOCKED_COLOR
	_detail.add_child(portrait)
	var name_label: Label = UiStyle.make_label(NAME_SIZE)
	name_label.text = tr(character.name_key) if unlocked else tr("LOCKED")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(name_label)
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.add_theme_font_override("normal_font", UiStyle.FONT)
	text.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	if unlocked:
		var weapons: PackedStringArray = []
		for weapon: WeaponData in character.starting_weapons:
			weapons.append(tr(weapon.name_key))
		text.text = "%s\n\n%s: %s\n%s" % [TextFormat.describe_character(character), tr("RUN_END_WEAPONS"),
			", ".join(weapons), _wins_text(character)]
	else:
		var progress: String = Unlocks.progress_text(character)
		text.text = Unlocks.condition_text(character) + ("\n" + tr("CHALLENGE_PROGRESS") % progress if progress != "" else "")
	_detail.add_child(text)
	if _confirm != null:
		_confirm.disabled = not unlocked


## "Gewonnen auf Spannung: 0, 2" oder "Noch kein Sieg".
func _wins_text(character: CharacterData) -> String:
	var levels: Array[int] = SaveManager.get_won_difficulties(character.id)
	if levels.is_empty():
		return tr("WINS_NONE")
	return tr("WINS_LEVELS") % ", ".join(levels.map(func(l: int) -> String: return str(l)))


func _confirm_character() -> void:
	if not Unlocks.is_unlocked(_character):
		return
	if _character.starting_weapons.size() > 1:
		_show_step(Step.WEAPON)
	else:
		_weapon = _character.starting_weapons[0] if not _character.starting_weapons.is_empty() else null
		_show_step(Step.DIFFICULTY)


# --- Startwaffe ---

func _build_weapons() -> void:
	_title(tr("SELECT_WEAPON"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	var first: Button = null
	for weapon: WeaponData in _character.starting_weapons:
		var card: OfferCard = OfferCard.new()
		card.configure(weapon.texture, tr(weapon.name_key), WeaponData.MIN_TIER, TextFormat.describe_weapon(weapon, WeaponData.MIN_TIER))
		var button: Button = card.add_action(tr("CHOOSE"), _choose_weapon.bind(weapon))
		if first == null or weapon == _weapon:
			first = button
		row.add_child(card)
	_add_button(_button_row(), tr("BACK"), _back)
	first.call_deferred("grab_focus")


func _choose_weapon(weapon: WeaponData) -> void:
	_weapon = weapon
	_show_step(Step.DIFFICULTY)


# --- Spannung ---

func _build_difficulties() -> void:
	_title(tr("SELECT_DIFFICULTY"))
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP / 2)
	_content.add_child(list)
	var current: int = GameState.difficulty.level if GameState.difficulty != null else 0
	var focus: Button = null
	for level in DIFFICULTY_COUNT:
		var difficulty: DifficultyData = load(DIFFICULTY_PATH % level)
		var button: Button = UiStyle.make_button("%s – %s" % [tr(difficulty.name_key), tr(difficulty.description_key)], TEXT_SIZE)
		button.custom_minimum_size = Vector2(DIFFICULTY_WIDTH, 0.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_start_run.bind(difficulty))
		list.add_child(button)
		if level == current:
			focus = button
	_add_button(_button_row(), tr("BACK"), _back)
	focus.call_deferred("grab_focus")


func _start_run(difficulty: DifficultyData) -> void:
	GameState.set_run_setup(_character, _weapon, difficulty)
	GameState.resume_data = {}
	SaveManager.clear_run()
	get_tree().change_scene_to_file(RUN_SCENE)


# --- Hilfen ---

func _title(text: String) -> void:
	var label: Label = UiStyle.make_label(TITLE_SIZE)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(label)


func _button_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP)
	_content.add_child(row)
	return row


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = UiStyle.make_button(text, TEXT_SIZE)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
