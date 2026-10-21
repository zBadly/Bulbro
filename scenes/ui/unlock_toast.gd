class_name UnlockToast
extends CanvasLayer
## Popup "Neu freigeschaltet": fährt oben rechts herein, bleibt kurz und verschwindet. Mehrere werden nacheinander gezeigt.

const SCREEN_MARGIN: float = 24.0
const PANEL_WIDTH: float = 420.0
const ICON_SIZE: Vector2 = Vector2(56, 64)
const TITLE_SIZE: int = 20
const NAME_SIZE: int = 28
const SLIDE_TIME: float = 0.35
const HOLD_TIME: float = 2.6
const BORDER_WIDTH: int = 4
const ACCENT: Color = Color("#7ED957")

var _queue: Array[ChallengeData] = []
var _showing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	Events.challenge_completed.connect(_on_challenge_completed)


func _on_challenge_completed(challenge: ChallengeData) -> void:
	_queue.append(challenge)
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var challenge: ChallengeData = _queue.pop_front()
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.panel_style()
	style.border_color = ACCENT
	style.set_border_width_all(BORDER_WIDTH)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(SCREEN_MARGIN / 2))
	panel.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.texture = challenge.reward_icon()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var texts: VBoxContainer = VBoxContainer.new()
	row.add_child(texts)
	var title: Label = UiStyle.make_label(TITLE_SIZE, ACCENT)
	title.text = tr("UNLOCKED_TOAST")
	texts.add_child(title)
	var name_label: Label = UiStyle.make_label(NAME_SIZE)
	name_label.text = challenge.reward_name()
	texts.add_child(name_label)
	AudioManager.play(&"level_up")

	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var shown_x: float = viewport_width - PANEL_WIDTH - SCREEN_MARGIN
	panel.position = Vector2(viewport_width, SCREEN_MARGIN)
	var tween: Tween = create_tween()
	tween.tween_property(panel, "position:x", shown_x, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(panel, "position:x", viewport_width, SLIDE_TIME).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		panel.queue_free()
		_show_next())
