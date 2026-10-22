class_name HitboxOverlay
extends Node2D
## Admin: zeichnet die Kollisionsformen aller Spielobjekte (Spieler, Gegner, Projektile, Pickups, Verbündete).
## Farbe nach Kollisionsebene; nur sichtbar, solange GameState.admin.show_hitboxes an ist.

const LINE_WIDTH: float = 2.0
const DRAW_Z_INDEX: int = 4000
## Kollisionsebene (Bit-Index ab 1) -> Farbe.
const LAYER_COLORS: Dictionary[int, Color] = {
	1: Color("#7ED957"), 2: Color("#E74C3C"), 3: Color("#FFD43B"), 4: Color("#FF9F43"),
	5: Color("#4AE2D9"), 7: Color("#C9CED3"), 8: Color("#4A90E2"),
}
const DEFAULT_COLOR: Color = Color("#FFFFFF")

## Teilbaum, dessen Formen gezeichnet werden (die Arena).
var root: Node


func _ready() -> void:
	z_index = DRAW_Z_INDEX
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	visible = GameState.admin.show_hitboxes
	if visible:
		queue_redraw()


func _draw() -> void:
	if root != null:
		_draw_shapes(root)


func _draw_shapes(node: Node) -> void:
	var canvas_item: CanvasItem = node as CanvasItem
	if canvas_item != null and not canvas_item.visible:
		return
	var shape_node: CollisionShape2D = node as CollisionShape2D
	if shape_node != null and shape_node.shape != null and not shape_node.disabled:
		_draw_shape(shape_node)
	for child: Node in node.get_children():
		_draw_shapes(child)


func _draw_shape(shape_node: CollisionShape2D) -> void:
	var color: Color = _color_for(shape_node.get_parent() as CollisionObject2D)
	var at: Vector2 = to_local(shape_node.global_position)
	var scale_factor: float = shape_node.global_scale.x
	var circle: CircleShape2D = shape_node.shape as CircleShape2D
	if circle != null:
		draw_arc(at, circle.radius * scale_factor, 0.0, TAU, 24, color, LINE_WIDTH)
		return
	var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
	if rect != null:
		var size: Vector2 = rect.size * scale_factor
		draw_rect(Rect2(at - size * 0.5, size), color, false, LINE_WIDTH)


func _color_for(body: CollisionObject2D) -> Color:
	if body == null:
		return DEFAULT_COLOR
	for layer: int in LAYER_COLORS:
		if body.get_collision_layer_value(layer):
			return LAYER_COLORS[layer]
	return DEFAULT_COLOR
