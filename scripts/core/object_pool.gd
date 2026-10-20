class_name ObjectPool
extends Node
## Wiederverwendbare Instanzen einer Szene (Projektile, Schadenszahlen, später Gegner und Pickups).
## Freie Instanzen sind versteckt und deaktiviert (PROCESS_MODE_DISABLED entfernt sie auch aus der Physik).
## Hat die Instanz eine Eigenschaft "pool", wird sie beim Holen auf diesen Pool gesetzt.

@export var scene: PackedScene
## Gruppe, über die andere Systeme den Pool finden (siehe Pools).
@export var group_name: StringName

var _free: Array[Node] = []


func _ready() -> void:
	if group_name != &"":
		add_to_group(group_name)


func prewarm(count: int) -> void:
	for i in count:
		var node: Node = _create()
		_deactivate(node)
		_free.append(node)


func acquire() -> Node:
	var node: Node = _free.pop_back() if not _free.is_empty() else _create()
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is CanvasItem:
		(node as CanvasItem).show()
	return node


func release(node: Node) -> void:
	if node == null or _free.has(node):
		return
	_deactivate(node)
	_free.append(node)


func free_count() -> int:
	return _free.size()


func _create() -> Node:
	var node: Node = scene.instantiate()
	if &"pool" in node:
		node.set(&"pool", self)
	add_child(node)
	return node


func _deactivate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		(node as CanvasItem).hide()
