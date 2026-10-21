class_name Fx
extends RefCounted
## Kurzlebige Effekt-Grafiken (Blitz, Explosion). Werden in den Knoten der Gruppe FX_GROUP gehängt;
## ohne solchen Knoten (z. B. in Tests) passiert nichts.

const FX_GROUP: StringName = &"fx_layer"
const LIGHTNING_COLOR: Color = Color("#BFF3FF")
const LIGHTNING_OUTLINE: Color = Color("#4A90E2")
const LIGHTNING_CORE: Color = Color("#FFFFFF")
const LIGHTNING_WIDTH: float = 4.0
const LIGHTNING_SEGMENTS: int = 6
## Weitere Zacken pro 100 px Länge, damit lange Sprünge nicht glatt wirken.
const LIGHTNING_SEGMENTS_PER_100: float = 0.8
const LIGHTNING_JITTER: float = 16.0
const LIGHTNING_TIME: float = 0.18


const JUICE_HOST_GROUP: StringName = &"juice_host"
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
## Über der Spielwelt, unter HUD und Menüs.
const FLASH_LAYER: int = 5


## Partikel-Effekt (siehe ParticleFx.Kind) an einer Position, optional in eine Richtung.
static func particles(tree: SceneTree, kind: int, at: Vector2, direction: Vector2 = Vector2.ZERO) -> void:
	var emitters: ParticleFx = tree.get_first_node_in_group(ParticleFx.GROUP) as ParticleFx
	if emitters != null:
		emitters.emit(kind, at, direction)


## Bildschirmwackeln (Trauma 0..1, addiert sich).
static func shake(tree: SceneTree, trauma: float) -> void:
	var host: Node = tree.get_first_node_in_group(JUICE_HOST_GROUP)
	if host != null:
		host.call("add_trauma", trauma)


## Kurzer Hit-Stop (Zeitlupe für wenige Millisekunden), z. B. bei Krits.
static func hit_stop(tree: SceneTree) -> void:
	var host: Node = tree.get_first_node_in_group(JUICE_HOST_GROUP)
	if host != null:
		host.call("hit_stop")


static func layer(tree: SceneTree) -> Node2D:
	return tree.get_first_node_in_group(FX_GROUP) as Node2D


static func lightning(tree: SceneTree, from: Vector2, to: Vector2) -> void:
	var parent: Node2D = layer(tree)
	if parent == null:
		return
	var points: PackedVector2Array = [from]
	var normal: Vector2 = (to - from).orthogonal().normalized()
	var segments: int = LIGHTNING_SEGMENTS + floori(from.distance_to(to) / 100.0 * LIGHTNING_SEGMENTS_PER_100)
	var side: float = 1.0 if randf() < 0.5 else -1.0
	for i in range(1, segments):
		var t: float = (i + randf_range(-0.35, 0.35)) / segments
		side = -side if randf() < 0.75 else side
		points.append(from.lerp(to, t) + normal * side * LIGHTNING_JITTER * randf_range(0.2, 1.0))
	points.append(to)
	for layer_def: Array in [[LIGHTNING_OUTLINE, LIGHTNING_WIDTH * 2.0], [LIGHTNING_COLOR, LIGHTNING_WIDTH], [LIGHTNING_CORE, LIGHTNING_WIDTH * 0.4]]:
		var line: Line2D = Line2D.new()
		line.points = points
		line.default_color = layer_def[0]
		line.width = layer_def[1]
		line.joint_mode = Line2D.LINE_JOINT_SHARP
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		parent.add_child(line)
		var tween: Tween = line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, LIGHTNING_TIME)
		tween.finished.connect(line.queue_free)


## Funken an einem Ziel des Kettenblitzes.
static func zap(tree: SceneTree, at: Vector2) -> void:
	particles(tree, ParticleFx.Kind.ZAP, at)


## Feuerball fliegt von `from` nach `to` und ruft dort `on_arrive` auf. Ohne Effekt-Ebene sofort.
static func fireball(tree: SceneTree, from: Vector2, to: Vector2, speed: float, on_arrive: Callable) -> void:
	var parent: Node2D = layer(tree)
	if parent == null or speed <= 0.0:
		on_arrive.call()
		return
	var fx: FireballFx = FireballFx.new()
	parent.add_child(fx)
	fx.launch(from, to, speed, on_arrive)


## Eisring mit Zacken und Splittern (Frostnova).
static func frost_nova(tree: SceneTree, position: Vector2, radius: float) -> void:
	var parent: Node2D = layer(tree)
	if parent == null:
		return
	var fx: FrostNovaFx = FrostNovaFx.new()
	parent.add_child(fx)
	fx.play(position, radius)
	particles(tree, ParticleFx.Kind.ICE_BURST, position)


## Ring, der kurz aufleuchtet (z. B. Heilung des Flackerers).
static func pulse(tree: SceneTree, position: Vector2, radius: float, color: Color) -> void:
	var parent: Node2D = layer(tree)
	if parent == null:
		return
	var fx: ExplosionFx = ExplosionFx.new()
	fx.fill_color = Color(color, 0.25)
	fx.ring_color = color
	parent.add_child(fx)
	fx.play(position, radius)


## Rote, pulsierende Warnzone am Boden (Finsternis); verschwindet nach `duration`.
static func zone_warning(tree: SceneTree, position: Vector2, radius: float, duration: float) -> void:
	var parent: Node2D = layer(tree)
	if parent == null:
		return
	var zone: ZoneWarningFx = ZoneWarningFx.new()
	parent.add_child(zone)
	zone.play(position, radius, duration)


static func explosion(tree: SceneTree, position: Vector2, radius: float) -> void:
	var parent: Node2D = layer(tree)
	if parent == null:
		return
	var fx: ExplosionFx = ExplosionFx.new()
	parent.add_child(fx)
	fx.play(position, radius)


## Kurzer heller Blitz über den ganzen Bildschirm (Stroboskop). Schwach genug, um nicht zu blenden;
## mit der Option "Effekte reduzieren" noch deutlich schwächer.
static func screen_flash(tree: SceneTree) -> void:
	var parent: Node2D = layer(tree)
	if parent == null:
		return
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = FLASH_LAYER
	var rect: ColorRect = ColorRect.new()
	rect.color = STATUS.flash_color
	if SaveManager.get_option(SaveManager.REDUCED_FX_KEY, false):
		rect.color.a *= STATUS.flash_reduced_factor
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)
	parent.add_child(canvas)
	var tween: Tween = rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, STATUS.flash_time)
	tween.finished.connect(canvas.queue_free)
