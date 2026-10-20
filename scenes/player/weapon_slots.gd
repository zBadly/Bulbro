class_name WeaponSlots
extends Node2D
## Verwaltet bis zu max_slots Waffen, die gleichmäßig im Kreis um Bulbro schweben.

signal weapons_changed

const WEAPON_SCENE: PackedScene = preload("res://scenes/weapons/weapon.tscn")

var player: Player
var max_slots: int = 0
var orbit_radius: float = 0.0

var _weapons: Array[Weapon] = []


func is_full() -> bool:
	return _weapons.size() >= max_slots


func get_weapons() -> Array[Weapon]:
	return _weapons.duplicate()


func count_of(weapon_id: StringName) -> int:
	var count: int = 0
	for weapon: Weapon in _weapons:
		if weapon.data.id == weapon_id:
			count += 1
	return count


## Fügt eine Waffe hinzu. Gibt null zurück, wenn alle Slots belegt sind.
func add_weapon(data: WeaponData, tier: int = WeaponData.MIN_TIER) -> Weapon:
	if is_full():
		return null
	var weapon: Weapon = WEAPON_SCENE.instantiate() as Weapon
	weapon.setup(data, tier, player)
	_weapons.append(weapon)
	add_child(weapon)
	_layout()
	weapons_changed.emit()
	return weapon


func remove_weapon(weapon: Weapon) -> void:
	if not _weapons.has(weapon):
		return
	_weapons.erase(weapon)
	weapon.queue_free()
	_layout()
	weapons_changed.emit()


func _layout() -> void:
	var count: int = _weapons.size()
	for i in count:
		var weapon: Weapon = _weapons[i]
		weapon.rest_position = Vector2.from_angle(TAU * i / count) * orbit_radius
		if not weapon.is_attacking():
			weapon.position = weapon.rest_position
