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
	remove_child(weapon)
	weapon.queue_free()
	_layout()
	weapons_changed.emit()


## Partner zum Kombinieren: gleiche Waffe, gleiches Tier, noch nicht Tier IV.
func find_combine_partner(data: WeaponData, tier: int, exclude: Weapon = null) -> Weapon:
	if tier >= WeaponData.MAX_TIER:
		return null
	for weapon: Weapon in _weapons:
		if weapon != exclude and weapon.data.id == data.id and weapon.tier == tier:
			return weapon
	return null


## Kann diese Waffe gekauft werden (freier Slot oder automatisches Kombinieren)?
func can_accept(data: WeaponData, tier: int) -> bool:
	if player != null and not player.can_use_weapon(data):
		return false
	return not is_full() or find_combine_partner(data, tier) != null


## Kauf: freier Slot -> hinzufügen; Slots voll -> automatisch mit gleicher Waffe gleichen Tiers kombinieren.
func add_or_combine(data: WeaponData, tier: int) -> Weapon:
	if not is_full():
		return add_weapon(data, tier)
	var partner: Weapon = find_combine_partner(data, tier)
	if partner == null:
		return null
	remove_weapon(partner)
	return add_weapon(data, tier + 1)


## Kombiniert eine Waffe mit einer gleichen gleichen Tiers zur nächsthöheren Stufe.
func combine(weapon: Weapon) -> Weapon:
	var partner: Weapon = find_combine_partner(weapon.data, weapon.tier, weapon)
	if partner == null:
		return null
	var data: WeaponData = weapon.data
	var tier: int = weapon.tier + 1
	remove_weapon(weapon)
	remove_weapon(partner)
	return add_weapon(data, tier)


func _layout() -> void:
	var count: int = _weapons.size()
	for i in count:
		var weapon: Weapon = _weapons[i]
		weapon.rest_position = Vector2.from_angle(TAU * i / count) * orbit_radius
		if not weapon.is_attacking():
			weapon.position = weapon.rest_position
