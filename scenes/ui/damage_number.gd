class_name DamageNumber
extends Node2D
## Gepoolte Schadenszahl: steigt auf und verblasst. Krits sind gelb und größer.

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")

var pool: ObjectPool

var _tween: Tween

@onready var _label: Label = $Label


func _ready() -> void:
	z_index = COMBAT.damage_number_z_index
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_color_override("font_outline_color", COMBAT.damage_number_outline_color)
	_label.add_theme_constant_override("outline_size", COMBAT.damage_number_outline_size)


func show_damage(amount: int, is_crit: bool, world_position: Vector2) -> void:
	_label.text = str(amount)
	_label.add_theme_font_size_override("font_size",
		COMBAT.damage_number_crit_font_size if is_crit else COMBAT.damage_number_font_size)
	_label.add_theme_color_override("font_color",
		COMBAT.damage_number_crit_color if is_crit else COMBAT.damage_number_color)
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
