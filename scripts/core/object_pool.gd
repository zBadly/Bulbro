class_name ObjectPool
extends Node
## Wiederverwendbare Instanzen einer Szene (Projektile, Schadenszahlen, Gegner, Pickups).
## Freie Instanzen sind versteckt und deaktiviert (PROCESS_MODE_DISABLED entfernt sie auch aus der Physik).
## Hat die Instanz eine Eigenschaft "pool", wird sie beim Erzeugen auf diesen Pool gesetzt.

@export var scene: PackedScene
## Gruppe, über die andere Systeme den Pool finden (siehe Pools).
@export var group_name: StringName

## Elternknoten der Instanzen. Standard: der Pool selbst. Für Y-Sortierung z. B. den Entities-Knoten setzen.
var container: Node
## Wird einmalig mit jeder neu erzeugten Instanz aufgerufen (nach add_child).
var on_create: Callable

var _free: Array[Node] = []
var _active: Array[Node] = []


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
	_set_process_mode(node, Node.PROCESS_MODE_INHERIT)
	if node is CanvasItem:
		(node as CanvasItem).show()
	_active.append(node)
	return node


func release(node: Node) -> void:
	if node == null or _free.has(node):
		return
	_active.erase(node)
	_deactivate(node)
	_free.append(node)


## Gibt alle aktiven Instanzen zurück (z. B. am Wellenende).
func release_all() -> void:
	for node: Node in _active.duplicate():
		release(node)


func free_count() -> int:
	return _free.size()


func active_count() -> int:
	return _active.size()


func get_active() -> Array[Node]:
	return _active.duplicate()


## Während eines Physik-Frames (z. B. in body_entered) darf der Physikzustand nicht direkt geändert werden.
func _set_process_mode(node: Node, mode: Node.ProcessMode) -> void:
	if Engine.is_in_physics_frame():
		node.set_deferred(&"process_mode", mode)
	else:
		node.process_mode = mode


func _create() -> Node:
	var node: Node = scene.instantiate()
	if &"pool" in node:
		node.set(&"pool", self)
	(container if container != null else self).add_child(node)
	if on_create.is_valid():
		on_create.call(node)
	return node


func _deactivate(node: Node) -> void:
	_set_process_mode(node, Node.PROCESS_MODE_DISABLED)
	if node is CanvasItem:
		(node as CanvasItem).hide()
