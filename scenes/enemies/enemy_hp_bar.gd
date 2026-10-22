class_name EnemyHpBar
extends Node2D
## Kleine HP-Leiste unter einem normalen Gegner (Elites und Bosse haben die große Leiste oben im HUD).
## Zeichnet nur bei HP-Änderungen neu (zwei Rechtecke), damit 100 Gegner nichts kosten.
## Anzeige-Modus aus den Optionen: immer, nur nach Schaden (Standard) oder aus.

enum Mode { ALWAYS, DAMAGED, OFF }

const CONFIG: HudConfig = preload("res://data/config/hud_config.tres")
const DEFAULT_MODE: Mode = Mode.DAMAGED
const GROUP: StringName = &"enemy_hp_bars"
## Übersetzungsschlüssel der Modi für die Optionen (Reihenfolge wie Mode).
const MODE_KEYS: PackedStringArray = ["OPT_HP_BARS_ALWAYS", "OPT_HP_BARS_DAMAGED", "OPT_HP_BARS_OFF"]

## Gilt für alle Leisten; die Arena setzt ihn beim Start und nach Änderungen in den Optionen.
static var mode: Mode = DEFAULT_MODE

var _width: float = 0.0
var _ratio: float = 1.0


## Breite aus dem Kollisionsradius des Gegners.
func setup(collision_radius: float) -> void:
	_width = clampf(collision_radius * 2.0 * CONFIG.enemy_bar_width_factor, CONFIG.enemy_bar_min_width, CONFIG.enemy_bar_max_width)
	position = Vector2(0.0, CONFIG.enemy_bar_gap)
	z_index = 1
	add_to_group(GROUP)


func reset() -> void:
	set_ratio(1.0)


func set_ratio(ratio: float) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	if clamped != _ratio:
		_ratio = clamped
		queue_redraw()
	visible = should_show(mode, _ratio)


## Sichtbarkeit nach Modus und HP-Anteil (pur, für Tests).
static func should_show(p_mode: Mode, ratio: float) -> bool:
	match p_mode:
		Mode.ALWAYS:
			return ratio > 0.0
		Mode.DAMAGED:
			return ratio > 0.0 and ratio < 1.0
	return false


func refresh_mode() -> void:
	visible = should_show(mode, _ratio)


func _draw() -> void:
	var outline: float = CONFIG.enemy_bar_outline
	var height: float = CONFIG.enemy_bar_height
	var rect: Rect2 = Rect2(-_width * 0.5 - outline, -outline, _width + outline * 2.0, height + outline * 2.0)
	draw_rect(rect, CONFIG.enemy_bar_outline_color)
	draw_rect(Rect2(-_width * 0.5, 0.0, _width, height), CONFIG.enemy_bar_background)
	draw_rect(Rect2(-_width * 0.5, 0.0, _width * _ratio, height), CONFIG.enemy_bar_fill)
