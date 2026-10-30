class_name TowerBuilder
extends Node
## Baut Strukturen in der Arena (Phase 15, Paket 8): zu Wellenbeginn die Lampentürme der Waffen und die
## Türme der Items (jedes Exemplar ein Turm), zufällig in einem Ring um den Spieler, innerhalb der Arena und
## mit Mindestabstand. Hält die Obergrenzen für Türme und Minen (TowerConfig) ein.
## Für die Freischaltungen (Taschenlampe, Drohnenleuchte) zählen ausdrücklich nur Lampentürme.

const STRUCTURE_SCENE: PackedScene = preload("res://scenes/structures/structure.tscn")
const TOWERS: TowerConfig = preload("res://data/config/tower_config.tres")
const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
## Nur dieser Turm zählt für "Lampentürme gleichzeitig" und "Lampentürme am Run-Ende".
const UNLOCK_TOWER_ID: StringName = &"lampenturm"

var player: Player
## Knoten für Türme und Minen (y-sortierte Entities) und für Auren (Boden).
var container: Node2D
var ground: Node2D
var area: Rect2

var _structures: Array[Structure] = []
var _mines: Array[Mine] = []


## Zu Wellenbeginn: alles abbauen, dann Waffen-Lampentürme und Item-Türme bis zur Obergrenze bauen.
func build_wave() -> void:
	clear()
	GameState.run_stats.current_turrets = 0
	var requests: Array[Array] = wave_requests()
	for request: Array in requests.slice(0, TOWERS.max_towers):
		build(request[0], request[1], place())


## Was zu Wellenbeginn gebaut wird, in Reihenfolge: [StructureData, Tier] je Turm.
func wave_requests() -> Array[Array]:
	var result: Array[Array] = []
	for weapon: Weapon in player.weapon_slots.get_weapons():
		if weapon.data.structure != null:
			result.append([weapon.data.structure, weapon.tier])
	for item: ItemData in GameState.items:
		for effect: ItemEffect in item.effects:
			if effect is TowerItemEffect:
				result.append([(effect as TowerItemEffect).structure, 1])
	return result


## Freier Platz im Ring um den Spieler, innerhalb der Arena. Findet sich keiner mit Mindestabstand,
## gewinnt der Versuch mit dem größten Abstand zum nächsten Turm.
func place() -> Vector2:
	var rng: RandomNumberGenerator = GameState.rng
	var inner: Rect2 = area.grow(-TOWERS.edge_margin)
	var center: Vector2 = player.global_position
	var best: Vector2 = center.clamp(inner.position, inner.end)
	var best_gap: float = -1.0
	for i in TOWERS.placement_tries:
		var at: Vector2 = center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(TOWERS.ring_min_radius, TOWERS.ring_max_radius)
		at = at.clamp(inner.position, inner.end)
		var gap: float = _gap(at)
		if gap >= TOWERS.min_spacing:
			return at
		if gap > best_gap:
			best_gap = gap
			best = at
	return best


func _gap(at: Vector2) -> float:
	var gap: float = INF
	for structure: Structure in towers():
		gap = minf(gap, structure.position.distance_to(at))
	return gap


## Baut eine Struktur. Ranken haben eine eigene Höchstzahl (die älteste verschwindet), Türme die Obergrenze
## aus der TowerConfig (darüber wird nichts gebaut).
func build(data: StructureData, tier: int, at: Vector2) -> Structure:
	_prune()
	if data.max_count > 0:
		var same: Array[Structure] = _structures.filter(func(s: Structure) -> bool: return s.data == data)
		if same.size() >= data.max_count:
			same[0].queue_free()
			_structures.erase(same[0])
	if data.is_tower() and towers().size() >= TOWERS.max_towers:
		return null
	var inner: Rect2 = area.grow(-TOWERS.edge_margin)
	var structure: Structure = STRUCTURE_SCENE.instantiate() as Structure
	structure.setup(data, tier, player)
	structure.ground = ground
	structure.position = at.clamp(inner.position, inner.end)
	structure.mine_requested.connect(_on_mine_requested)
	container.add_child.call_deferred(structure)
	_structures.append(structure)
	_record_lamp_towers()
	return structure


## Türme ohne Ranken (gebaut und noch nicht abgebaut).
func towers() -> Array[Structure]:
	_prune()
	return _structures.filter(func(s: Structure) -> bool: return s.data.is_tower())


func mines() -> Array[Mine]:
	var live: Array[Mine] = []
	for mine: Variant in _mines:
		if is_instance_valid(mine) and not (mine as Mine).is_queued_for_deletion():
			live.append(mine)
	_mines = live
	return _mines


func lamp_tower_count() -> int:
	return towers().filter(func(s: Structure) -> bool: return s.data.id == UNLOCK_TOWER_ID).size()


## Freischaltungen: Höchststand und aktueller Stand der Lampentürme (andere Türme zählen nicht).
func _record_lamp_towers() -> void:
	var lamps: int = lamp_tower_count()
	GameState.max_structures = maxi(GameState.max_structures, lamps)
	GameState.run_stats.current_turrets = lamps


func add_mine(data: StructureData, at: Vector2) -> Mine:
	var live: Array[Mine] = mines()
	if live.size() >= TOWERS.max_mines:
		live[0].queue_free()
		live.remove_at(0)
	var inner: Rect2 = area.grow(-TOWERS.edge_margin)
	var mine: Mine = Mine.new()
	mine.setup(data, player)
	mine.position = at.clamp(inner.position, inner.end)
	container.add_child(mine)
	_mines.append(mine)
	return mine


func _on_mine_requested(structure: Structure, at: Vector2) -> void:
	add_mine(structure.data, at)


func clear() -> void:
	for structure: Structure in _structures:
		if is_instance_valid(structure):
			structure.queue_free()
	_structures.clear()
	for mine: Mine in _mines:
		if is_instance_valid(mine):
			mine.queue_free()
	_mines.clear()


## Abgebaute und explodierte Knoten aussortieren (Variant: freigegebene Instanzen passen in keinen Typ).
func _prune() -> void:
	var live: Array[Structure] = []
	for structure: Variant in _structures:
		if is_instance_valid(structure) and not (structure as Structure).is_queued_for_deletion():
			live.append(structure)
	_structures = live
