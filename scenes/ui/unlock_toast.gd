class_name UnlockToast
extends CanvasLayer
## Popup "Neu freigeschaltet" bzw. "Achievement erreicht": fährt oben rechts herein, bleibt kurz und verschwindet.
## Kommen mehrere gleichzeitig, stapeln sie sich untereinander (höchstens MAX_VISIBLE, der Rest wartet).

const SCREEN_MARGIN: float = 24.0
const PANEL_WIDTH: float = 420.0
const ICON_SIZE: Vector2 = Vector2(56, 64)
const TITLE_SIZE: int = 20
const NAME_SIZE: int = 28
const SLIDE_TIME: float = 0.35
const HOLD_TIME: float = 2.6
const BORDER_WIDTH: int = 4
const ACCENT: Color = Color("#7ED957")
const ACHIEVEMENT_ACCENT: Color = Color("#F5A623")
const MAX_VISIBLE: int = 4
## Abstand zwischen gestapelten Popups und Versatz beim Hereinfahren mehrerer auf einmal.
const STACK_GAP: float = 12.0
const STAGGER_TIME: float = 0.15
## Feste Popup-Höhe, damit die Stapelplätze nicht von der Textlänge abhängen.
const PANEL_HEIGHT: float = 96.0

var _queue: Array[ChallengeData] = []
## Belegte Stapelplätze (Index -> Popup).
var _slots: Dictionary[int, PanelContainer] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	Events.challenge_completed.connect(_on_challenge_completed)


func _on_challenge_completed(challenge: ChallengeData) -> void:
	_queue.append(challenge)
	_fill_slots()


## Zahl der gerade sichtbaren Popups (Tests).
func visible_count() -> int:
	return _slots.size()


func queued_count() -> int:
	return _queue.size()


func _fill_slots() -> void:
	var delay: float = 0.0
	for slot: int in MAX_VISIBLE:
		if _queue.is_empty():
			return
		if not _slots.has(slot):
			_show(_queue.pop_front(), slot, delay)
			delay += STAGGER_TIME


func _show(challenge: ChallengeData, slot: int, delay: float) -> void:
	var achievement: bool = challenge is AchievementData
	var accent: Color = (challenge as AchievementData).difficulty_color() if achievement else ACCENT
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.panel_style()
	style.border_color = accent
	style.set_border_width_all(BORDER_WIDTH)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	add_child(panel)
	_slots[slot] = panel
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
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var title: Label = UiStyle.make_label(TITLE_SIZE, ACHIEVEMENT_ACCENT if achievement else ACCENT)
	title.text = tr("ACHIEVEMENT_TOAST") if achievement else tr("UNLOCKED_TOAST")
	texts.add_child(title)
	var name_label: Label = UiStyle.make_label(NAME_SIZE)
	name_label.text = challenge.reward_name()
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	texts.add_child(name_label)

	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var shown_x: float = viewport_width - PANEL_WIDTH - SCREEN_MARGIN
	panel.position = Vector2(viewport_width, SCREEN_MARGIN + slot * (PANEL_HEIGHT + STACK_GAP))
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(AudioManager.play.bind(&"level_up"))
	tween.tween_property(panel, "position:x", shown_x, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(panel, "position:x", viewport_width, SLIDE_TIME).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		_slots.erase(slot)
		panel.queue_free()
		_fill_slots())
