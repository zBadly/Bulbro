class_name Juice
extends RefCounted
## Statische Tween-Helfer für Animation per Code (GDD Abschnitt 12).
## Alle Tweens hängen am animierten Node und enden automatisch, wenn er freigegeben wird.
## Animiere ein eigenes "Visual"-Kind, nicht den Physik-Body, damit Skalierung und Rotation die Kollision nicht verändern.

const IDLE_PERIOD: float = 0.6
const IDLE_SQUASH: Vector2 = Vector2(1.06, 0.94)
const WALK_TILT_DEG: float = 8.0
const WALK_BOB_SPEED: float = 2.0
const WALK_MIN_SPEED: float = 10.0
const TILT_TIME: float = 0.12
const DEATH_SQUASH: Vector2 = Vector2(1.35, 0.6)
const DEATH_POP: Vector2 = Vector2(1.2, 1.2)
const DEATH_SQUASH_TIME: float = 0.08
const DEATH_POP_TIME: float = 0.06
const DEATH_VANISH_TIME: float = 0.1
const SPAWN_POP_TIME: float = 0.25
const HIT_FLASH_TIME: float = 0.1
const MARKER_PULSE_PERIOD: float = 0.4
const MARKER_PULSE_SCALE: float = 1.2
const MARKER_PULSE_ALPHA: float = 0.55

const META_BASE_SCALE: StringName = &"juice_base_scale"
const META_BOB: StringName = &"juice_bob_tween"
const META_TILT: StringName = &"juice_tilt_tween"
const META_TILT_TARGET: StringName = &"juice_tilt_target"
const FLASH_PARAM: StringName = &"flash_amount"


## Sanftes Squash-Hüpfen in Endlosschleife. walk_tilt() beschleunigt es beim Laufen.
static func idle_bob(node: Node2D) -> Tween:
	_kill(node, META_BOB)
	var base: Vector2 = _base_scale(node)
	var tween: Tween = node.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", base * IDLE_SQUASH, IDLE_PERIOD * 0.5)
	tween.tween_property(node, "scale", base, IDLE_PERIOD * 0.5)
	node.set_meta(META_BOB, tween)
	return tween


## Jeden Frame mit der aktuellen Geschwindigkeit aufrufen: neigt den Node zur Laufrichtung
## und lässt ein laufendes idle_bob schneller hüpfen.
static func walk_tilt(node: Node2D, velocity: Vector2) -> void:
	var moving: bool = velocity.length() > WALK_MIN_SPEED
	var bob: Tween = _get_tween(node, META_BOB)
	if bob != null:
		bob.set_speed_scale(WALK_BOB_SPEED if moving else 1.0)

	var target: float = 0.0
	if absf(velocity.x) > WALK_MIN_SPEED:
		target = deg_to_rad(WALK_TILT_DEG) * signf(velocity.x)
	if node.has_meta(META_TILT_TARGET) and is_equal_approx(node.get_meta(META_TILT_TARGET), target):
		return
	node.set_meta(META_TILT_TARGET, target)
	_kill(node, META_TILT)
	var tween: Tween = node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation", target, TILT_TIME)
	node.set_meta(META_TILT, tween)


## Tod: zusammendrücken, kurz aufploppen, verschwinden. Der Aufrufer wartet auf finished und gibt den Node frei.
static func squash_pop(node: Node2D) -> Tween:
	_kill(node, META_BOB)
	var base: Vector2 = _base_scale(node)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", base * DEATH_SQUASH, DEATH_SQUASH_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base * DEATH_POP, DEATH_POP_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ZERO, DEATH_VANISH_TIME).set_ease(Tween.EASE_IN)
	return tween


## Pop-in mit Überschwingen von Skalierung 0 auf die Grundskalierung.
static func spawn_pop(node: Node2D) -> Tween:
	var base: Vector2 = _base_scale(node)
	node.scale = Vector2.ZERO
	var tween: Tween = node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base, SPAWN_POP_TIME)
	return tween


## Weißes Aufblitzen. Erwartet ein ShaderMaterial mit dem Parameter flash_amount.
static func hit_flash(item: CanvasItem) -> Tween:
	var mat: ShaderMaterial = item.material as ShaderMaterial
	if mat == null:
		return null
	var tween: Tween = item.create_tween()
	tween.tween_method(func(value: float) -> void: mat.set_shader_parameter(FLASH_PARAM, value), 1.0, 0.0, HIT_FLASH_TIME)
	return tween


## Pulsieren des Spawn-Markers (Skalierung und Transparenz) in Endlosschleife.
static func marker_pulse(node: Node2D) -> Tween:
	var base: Vector2 = _base_scale(node)
	var tween: Tween = node.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", base * MARKER_PULSE_SCALE, MARKER_PULSE_PERIOD * 0.5)
	tween.parallel().tween_property(node, "modulate:a", MARKER_PULSE_ALPHA, MARKER_PULSE_PERIOD * 0.5)
	tween.tween_property(node, "scale", base, MARKER_PULSE_PERIOD * 0.5)
	tween.parallel().tween_property(node, "modulate:a", 1.0, MARKER_PULSE_PERIOD * 0.5)
	return tween


static func _base_scale(node: Node2D) -> Vector2:
	if not node.has_meta(META_BASE_SCALE):
		node.set_meta(META_BASE_SCALE, node.scale)
	return node.get_meta(META_BASE_SCALE)


static func _get_tween(node: Node, key: StringName) -> Tween:
	if not node.has_meta(key):
		return null
	var tween: Tween = node.get_meta(key)
	return tween if tween != null and tween.is_valid() else null


static func _kill(node: Node, key: StringName) -> void:
	var tween: Tween = _get_tween(node, key)
	if tween != null:
		tween.kill()
	if node.has_meta(key):
		node.remove_meta(key)
