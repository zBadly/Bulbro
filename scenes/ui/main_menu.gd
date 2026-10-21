class_name MainMenu
extends Control
## Hauptmenü: Start (zur Charakterauswahl), Optionen, Beenden.

const RUN_SETUP_SCENE: String = "res://scenes/ui/run_setup.tscn"
const RUN_SCENE: String = "res://scenes/world/main.tscn"
const FLOOR_TEXTURE: Texture2D = preload("res://art/world/floor_tile.svg")
const HERO_TEXTURE: Texture2D = preload("res://art/characters/standardbirne.svg")
const HERO_SCALE: float = 2.5
const TITLE_SIZE: int = 140
const SUBTITLE_SIZE: int = 32
const BUTTON_SIZE: int = 36
const BUTTON_WIDTH: float = 320.0
const GAP: int = 18
const BOB_HEIGHT: float = 12.0
const BOB_TIME: float = 0.9
const TITLE_COLOR: Color = Color("#FFE066")

var _options: OptionsMenu


func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_music()
	_options = OptionsMenu.new()
	add_child(_options)
	_options.closed.connect(_build)
	_build()


func _build() -> void:
	for child: Node in get_children():
		if child != _options:
			child.queue_free()
	var floor_rect: TextureRect = TextureRect.new()
	floor_rect.texture = FLOOR_TEXTURE
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	floor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(floor_rect)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var hero_holder: Control = Control.new()
	hero_holder.custom_minimum_size = HERO_TEXTURE.get_size() * HERO_SCALE
	hero_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(hero_holder)
	var hero: TextureRect = TextureRect.new()
	hero.texture = HERO_TEXTURE
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.size = hero_holder.custom_minimum_size
	hero_holder.add_child(hero)
	var bob: Tween = hero.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(hero, "position:y", -BOB_HEIGHT, BOB_TIME)
	bob.tween_property(hero, "position:y", 0.0, BOB_TIME)

	var title: Label = UiStyle.make_label(TITLE_SIZE, TITLE_COLOR)
	title.text = tr("MENU_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle: Label = UiStyle.make_label(SUBTITLE_SIZE)
	subtitle.text = tr("MENU_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var first: Button = null
	if SaveManager.has_run():
		var run: Dictionary = SaveManager.load_run()
		var character: CharacterData = RunSave.find(Unlocks.CHARACTER_CATEGORY, run.get("character", "")) as CharacterData
		if character != null:
			first = _button(box, tr("MENU_CONTINUE") % [tr(character.name_key), int(run.get("wave", 0))], _continue_run)
	var start: Button = _button(box, tr("MENU_START"), func() -> void: get_tree().change_scene_to_file(RUN_SETUP_SCENE))
	_button(box, tr("MENU_OPTIONS"), _options.open)
	_button(box, tr("MENU_QUIT"), func() -> void: get_tree().quit())
	(first if first != null else start).call_deferred("grab_focus")


func _continue_run() -> void:
	var run: Dictionary = SaveManager.load_run()
	RunSave.apply_setup(run)
	GameState.resume_data = run
	get_tree().change_scene_to_file(RUN_SCENE)


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = UiStyle.make_button(text, BUTTON_SIZE)
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
