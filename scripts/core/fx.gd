class_name Fx
extends RefCounted
## Kurzlebige Effekt-Grafiken (Blitz, Explosion). Werden in den Knoten der Gruppe FX_GROUP gehängt;
## ohne solchen Knoten (z. B. in Tests) passiert nichts.

const FX_GROUP: StringName = &"fx_layer"
const LIGHTNING_COLOR: Color = Color("#BFF3FF")
const LIGHTNING_OUTLINE: Color = Color("#4A90E2")
const LIGHTNING_WIDTH: float = 4.0
const LIGHTNING_SEGMENTS: int = 6
const LIGHTNING_JITTER: float = 14.0
const LIGHTNING_TIME: float = 0.18


static func layer(tree: SceneTree) -> Node2D:
	return tree.get_first_node_in_group(FX_GROUP) as Node2D


static func lightning(tree: SceneTree, from: Vector2, to: Vector2) -> void:
	var parent: Node2D = layer(tree)
	if parent == null:
		return
	var points: PackedVector2Array = [from]
	var normal: Vector2 = (to - from).orthogonal().normalized()
	for i in range(1, LIGHTNING_SEGMENTS):
		var t: float = float(i) / LIGHTNING_SEGMENTS
		points.append(from.lerp(to, t) + normal * randf_range(-LIGHTNING_JITTER, LIGHTNING_JITTER))
	points.append(to)
	for layer_def: Array in [[LIGHTNING_OUTLINE, LIGHTNING_WIDTH * 2.0], [LIGHTNING_COLOR, LIGHTNING_WIDTH]]:
		var line: Line2D = Line2D.new()
		line.points = points
		line.default_color = layer_def[0]
		line.width = layer_def[1]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		parent.add_child(line)
		var tween: Tween = line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, LIGHTNING_TIME)
		tween.finished.connect(line.queue_free)


static func explosion(tree: SceneTree, position: Vector2, radius: float) -> void:
	var parent: Node2D = layer(tree)
	if parent == null:
		return
	var fx: ExplosionFx = ExplosionFx.new()
	parent.add_child(fx)
	fx.play(position, radius)
