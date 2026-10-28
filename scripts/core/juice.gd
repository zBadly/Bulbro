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
const TELEGRAPH_SQUASH: Vector2 = Vector2(1.2, 0.8)
const TELEGRAPH_RELEASE_TIME: float = 0.08
## Schweben (Irrlicht): Höhe und Dauer eines Auf-und-ab-Zyklus.
const HOVER_HEIGHT: float = 7.0
const HOVER_PERIOD: float = 1.4
const HOVER_STRETCH: Vector2 = Vector2(0.97, 1.04)
## Flackern: Helligkeits-/Alpha-Stufen mit ihren Dauern (unregelmäßig, wirkt wie eine Flamme).
const FLICKER_STEPS: Array[Vector2] = [Vector2(0.78, 0.07), Vector2(1.0, 0.11), Vector2(0.9, 0.05), Vector2(1.0, 0.23),
	Vector2(0.84, 0.06), Vector2(1.0, 0.16)]
## Nachschwingen (Kronleuchter-Kristalle): Feder mit Dämpfung.
const SWING_MAX_DEG: float = 14.0
const SWING_SPEED_REF: float = 450.0
const SWING_STIFFNESS: float = 90.0
const SWING_DAMPING: float = 7.0
const SWING_WOBBLE_DEG: float = 6.0
const SWING_WOBBLE_FREQ: float = 9.0
## Kurzes Aufleuchten bei einem Effekt (Stroboskop-Blitz).
const EFFECT_FLASH_TIME: float = 0.18

## Flattern (Leuchtkäfer): schneller Flügelschlag als Squash, dazu langsames Schweben und Pendeln.
const FLUTTER_PERIOD: float = 0.12
const FLUTTER_SQUASH: Vector2 = Vector2(1.12, 0.9)
const FLUTTER_HOVER: float = 5.0
const FLUTTER_HOVER_PERIOD: float = 0.9
const FLUTTER_WOBBLE_DEG: float = 7.0
## Rollen (Batterie-Igel): Drehung pro Pixel Weg; im Stand richtet er sich wieder auf.
const ROLL_RADIUS: float = 16.0
const ROLL_SETTLE_SPEED: float = 10.0
## Ducken (Schildkröte beim Blocken): flach drücken, halten, aufrichten.
const DUCK_SQUASH: Vector2 = Vector2(1.18, 0.62)
const DUCK_DOWN_TIME: float = 0.06
const DUCK_HOLD_TIME: float = 0.22
const DUCK_UP_TIME: float = 0.16
## Kleiner Hüpfer (Funkenspatz beim Einsammeln).
const HOP_HEIGHT: float = 10.0
const HOP_TIME: float = 0.18

const META_BASE_SCALE: StringName = &"juice_base_scale"
const META_FLUTTER: StringName = &"juice_flutter_tween"
const META_ACTION: StringName = &"juice_action_tween"
const META_BOB: StringName = &"juice_bob_tween"
const META_TILT: StringName = &"juice_tilt_tween"
const META_TILT_TARGET: StringName = &"juice_tilt_target"
const META_FLICKER: StringName = &"juice_flicker_tween"
const META_SWING_VELOCITY: StringName = &"juice_swing_velocity"
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
	_kill(node, META_FLUTTER)
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


## Warnung vor einer Aktion (z. B. Sprint): zusammendrücken, halten, zurückfedern. Ersetzt idle_bob und
## wird wie dieses von squash_pop abgebrochen.
static func telegraph(node: Node2D, hold_time: float) -> Tween:
	_kill(node, META_BOB)
	var base: Vector2 = _base_scale(node)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", base * TELEGRAPH_SQUASH, hold_time).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base, TELEGRAPH_RELEASE_TIME)
	tween.finished.connect(func() -> void: idle_bob(node), CONNECT_ONE_SHOT)
	node.set_meta(META_BOB, tween)
	return tween


## Schweben statt Hüpfen: sanftes Auf und Ab mit leichtem Strecken. Ersetzt idle_bob (gleicher Schlüssel),
## damit walk_tilt es beim Laufen beschleunigt und squash_pop es abbricht.
static func hover(node: Node2D) -> Tween:
	_kill(node, META_BOB)
	var base: Vector2 = _base_scale(node)
	var rest: float = node.position.y
	var tween: Tween = node.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", rest - HOVER_HEIGHT, HOVER_PERIOD * 0.5)
	tween.parallel().tween_property(node, "scale", base * HOVER_STRETCH, HOVER_PERIOD * 0.5)
	tween.tween_property(node, "position:y", rest, HOVER_PERIOD * 0.5)
	tween.parallel().tween_property(node, "scale", base, HOVER_PERIOD * 0.5)
	node.set_meta(META_BOB, tween)
	return tween


## Unregelmäßiges Flackern über self_modulate (Flamme). Läuft endlos.
static func flicker(item: CanvasItem) -> Tween:
	_kill(item, META_FLICKER)
	var tween: Tween = item.create_tween().set_loops()
	for step: Vector2 in FLICKER_STEPS:
		tween.tween_property(item, "self_modulate", Color(step.x, step.x, step.x, lerpf(1.0, step.x, 0.5)), step.y)
	item.set_meta(META_FLICKER, tween)
	return tween


## Jeden Frame aufrufen: lässt ein angehängtes Teil (Kristalle) gegen die Laufrichtung pendeln
## und beim Laufen leicht wackeln. Der Drehpunkt ist die Position des Nodes.
static func swing(node: Node2D, velocity: Vector2, delta: float) -> void:
	var angular: float = node.get_meta(META_SWING_VELOCITY, 0.0)
	var target: float = clampf(-velocity.x / SWING_SPEED_REF, -1.0, 1.0) * deg_to_rad(SWING_MAX_DEG)
	if velocity.length() > WALK_MIN_SPEED:
		target += sin(Time.get_ticks_msec() * 0.001 * SWING_WOBBLE_FREQ) * deg_to_rad(SWING_WOBBLE_DEG)
	angular += ((target - node.rotation) * SWING_STIFFNESS - angular * SWING_DAMPING) * delta
	node.rotation += angular * delta
	node.set_meta(META_SWING_VELOCITY, angular)


## Kurzes Aufleuchten bei einem Effekt: weißer Flash, etwas länger als ein Treffer.
static func effect_flash(item: CanvasItem) -> Tween:
	var mat: ShaderMaterial = item.material as ShaderMaterial
	if mat == null:
		return null
	var tween: Tween = item.create_tween()
	tween.tween_method(func(value: float) -> void: mat.set_shader_parameter(FLASH_PARAM, value), 1.0, 0.0, EFFECT_FLASH_TIME)
	return tween


## Flattern in Endlosschleife: schneller Flügel-Squash plus langsames Schweben mit leichtem Pendeln.
## Ersetzt idle_bob (gleicher Schlüssel); squash_pop bricht es ab.
static func flutter(node: Node2D) -> Tween:
	_kill(node, META_BOB)
	_kill(node, META_FLUTTER)
	var base: Vector2 = _base_scale(node)
	var flap: Tween = node.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	flap.tween_property(node, "scale", base * FLUTTER_SQUASH, FLUTTER_PERIOD * 0.5)
	flap.tween_property(node, "scale", base, FLUTTER_PERIOD * 0.5)
	node.set_meta(META_BOB, flap)
	var rest: float = node.position.y
	var drift: Tween = node.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(node, "position:y", rest - FLUTTER_HOVER, FLUTTER_HOVER_PERIOD * 0.5)
	drift.parallel().tween_property(node, "rotation", deg_to_rad(FLUTTER_WOBBLE_DEG), FLUTTER_HOVER_PERIOD * 0.5)
	drift.tween_property(node, "position:y", rest, FLUTTER_HOVER_PERIOD * 0.5)
	drift.parallel().tween_property(node, "rotation", -deg_to_rad(FLUTTER_WOBBLE_DEG), FLUTTER_HOVER_PERIOD * 0.5)
	node.set_meta(META_FLUTTER, drift)
	return flap


## Jeden Frame aufrufen: dreht den Node entlang der Bewegung wie eine rollende Kugel; im Stand richtet er sich auf.
static func roll(node: Node2D, velocity: Vector2, delta: float) -> void:
	if velocity.length() > WALK_MIN_SPEED:
		node.rotation = wrapf(node.rotation + velocity.length() * signf(velocity.x if velocity.x != 0.0 else 1.0) / ROLL_RADIUS * delta, -PI, PI)
	else:
		node.rotation = lerp_angle(node.rotation, 0.0, minf(1.0, ROLL_SETTLE_SPEED * delta))


## Ducken: flach drücken, kurz halten, wieder aufrichten. Läuft über ein laufendes idle_bob hinweg.
static func duck(node: Node2D) -> Tween:
	_kill(node, META_ACTION)
	var base: Vector2 = _base_scale(node)
	var bob: Tween = _get_tween(node, META_BOB)
	if bob != null:
		bob.pause()
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", base * DUCK_SQUASH, DUCK_DOWN_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DUCK_HOLD_TIME)
	tween.tween_property(node, "scale", base, DUCK_UP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void: _resume_bob(node), CONNECT_ONE_SHOT)
	node.set_meta(META_ACTION, tween)
	return tween


static func _resume_bob(node: Node2D) -> void:
	var bob: Tween = _get_tween(node, META_BOB)
	if bob != null:
		bob.play()


## Kleiner Hüpfer nach oben und zurück (unabhängig vom Squash des idle_bob).
static func hop(node: Node2D) -> Tween:
	if _get_tween(node, META_ACTION) != null:
		return null
	var rest: float = node.position.y
	var tween: Tween = node.create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "position:y", rest - HOP_HEIGHT, HOP_TIME * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position:y", rest, HOP_TIME * 0.5).set_ease(Tween.EASE_IN)
	node.set_meta(META_ACTION, tween)
	return tween


## Endlos-Animation (Hüpfen/Schweben) beenden und Lage zurücksetzen, z. B. vor einem Charakterwechsel.
static func stop_idle(node: Node2D) -> void:
	_kill(node, META_BOB)
	_kill(node, META_FLUTTER)
	node.position.y = 0.0
	node.scale = _base_scale(node)


static func stop_flicker(item: CanvasItem) -> void:
	_kill(item, META_FLICKER)
	item.self_modulate = Color.WHITE


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
