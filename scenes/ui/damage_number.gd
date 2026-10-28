class_name DamageNumber
extends Node2D
## Gepoolte Schadenszahl: steigt auf und verblasst. Krits sind gelb und größer.

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const PHASES: BossPhaseConfig = preload("res://data/config/boss_phase_config.tres")
const FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")

var pool: ObjectPool

var _tween: Tween
## Einmal pro Typ erzeugt: LabelSettings sind deutlich günstiger als Theme-Overrides pro Treffer.
static var _normal_settings: LabelSettings
static var _crit_settings: LabelSettings
static var _immune_settings: LabelSettings

@onready var _label: Label = $Label


func _ready() -> void:
	z_index = COMBAT.damage_number_z_index
	if _normal_settings == null:
		_normal_settings = _make_settings(COMBAT.damage_number_font_size, COMBAT.damage_number_color)
		_crit_settings = _make_settings(COMBAT.damage_number_crit_font_size, COMBAT.damage_number_crit_color)
		_immune_settings = _make_settings(COMBAT.damage_number_font_size, PHASES.immune_text_color)


static func _make_settings(font_size: int, color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font = FONT
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_color = COMBAT.damage_number_outline_color
	settings.outline_size = COMBAT.damage_number_outline_size
	return settings


func show_damage(amount: int, is_crit: bool, world_position: Vector2) -> void:
	_show(str(amount), _crit_settings if is_crit else _normal_settings, world_position)


## Graues "Immun": Treffer während der Unverwundbarkeit nach einem Phasenwechsel.
func show_immune(world_position: Vector2) -> void:
	_show(tr("IMMUNE_TEXT"), _immune_settings, world_position)


func _show(text: String, settings: LabelSettings, world_position: Vector2) -> void:
	_label.text = text
	_label.label_settings = settings
	_label.reset_size()
	_label.position = -_label.size * 0.5
	# Kosmetischer Versatz, bewusst nicht über den Run-RNG, damit Runs reproduzierbar bleiben.
	global_position = world_position + Vector2(randf_range(-1.0, 1.0) * COMBAT.damage_number_jitter, 0.0)
	modulate.a = 1.0
	scale = Vector2.ONE

	if _tween != null and _tween.is_valid():
		_tween.kill()
	var time: float = COMBAT.damage_number_time
	_tween = create_tween()
	_tween.tween_property(self, "position:y", position.y - COMBAT.damage_number_rise, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, time * 0.5).set_delay(time * 0.5)
	_tween.finished.connect(_on_finished)


func _on_finished() -> void:
	if pool != null:
		pool.release(self)
	else:
		queue_free()
