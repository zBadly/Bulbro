class_name PetSlots
extends Node
## Begleiter des Spielers (Phase 15, Paket 8): höchstens CONFIG.max_pets, Kombinieren wie bei Waffen.
## Die Begleiter stehen neben dem Spieler in der Welt (gleicher Elternknoten wie Spiegelbild und Drohnen) und
## werden mit dem Spieler entfernt. Player.rebuild() fasst sie nicht an, daher entstehen dabei keine doppelten.

signal pets_changed

const CONFIG: PetConfig = preload("res://data/config/pet_config.tres")
const PET_SCENE: PackedScene = preload("res://scenes/pets/pet.tscn")

var player: Player

var _pets: Array[Pet] = []


func get_pets() -> Array[Pet]:
	return _pets.duplicate()


func is_full() -> bool:
	return _pets.size() >= CONFIG.max_pets


## Fügt einen Begleiter hinzu. Gibt null zurück, wenn alle Plätze belegt sind.
func add_pet(data: PetData, tier: int = WeaponData.MIN_TIER) -> Pet:
	if is_full() or player == null:
		return null
	var pet: Pet = PET_SCENE.instantiate() as Pet
	pet.setup(data, tier, player, self)
	pet.slot_index = _free_slot()
	_pets.append(pet)
	var parent: Node = player.get_parent() if player.get_parent() != null else self
	parent.add_child(pet)
	pets_changed.emit()
	return pet


func remove_pet(pet: Pet) -> void:
	if not _pets.has(pet):
		return
	_pets.erase(pet)
	pet.dismiss()
	pets_changed.emit()


## Partner zum Kombinieren: gleicher Begleiter, gleiches Tier, noch nicht Tier IV.
func find_combine_partner(data: PetData, tier: int, exclude: Pet = null) -> Pet:
	if tier >= WeaponData.MAX_TIER:
		return null
	for pet: Pet in _pets:
		if pet != exclude and pet.data.id == data.id and pet.tier == tier:
			return pet
	return null


## Kann der Begleiter ohne Rückfrage dazukommen (freier Platz oder automatisches Kombinieren)?
func can_accept(data: PetData, tier: int) -> bool:
	return not is_full() or find_combine_partner(data, tier) != null


## Kauf: freier Platz -> hinzufügen; Plätze voll -> mit gleichem Begleiter gleichen Tiers kombinieren.
func add_or_combine(data: PetData, tier: int) -> Pet:
	if not is_full():
		return add_pet(data, tier)
	var partner: Pet = find_combine_partner(data, tier)
	if partner == null:
		return null
	remove_pet(partner)
	return add_pet(data, tier + 1)


## Kombiniert einen Begleiter mit einem gleichen gleichen Tiers zur nächsthöheren Stufe.
func combine(pet: Pet) -> Pet:
	var partner: Pet = find_combine_partner(pet.data, pet.tier, pet)
	if partner == null:
		return null
	var data: PetData = pet.data
	var tier: int = pet.tier + 1
	remove_pet(pet)
	remove_pet(partner)
	return add_pet(data, tier)


## Ersetzt `old` durch einen neuen Begleiter (Shop-Rückfrage bei vollen Plätzen).
func replace(old: Pet, data: PetData, tier: int) -> Pet:
	remove_pet(old)
	return add_pet(data, tier)


## Die Waffen des Spielers haben sich geändert (Mini-Birne kopiert die erste).
func refresh_weapons() -> void:
	for pet: Pet in _pets:
		if is_instance_valid(pet) and pet.is_node_ready():
			pet.data.behavior.on_weapons_changed(pet)


## Kleinster freier Ruheplatz, damit sich zwei Begleiter nie denselben Platz teilen.
func _free_slot() -> int:
	var used: Array[int] = []
	for pet: Pet in _pets:
		used.append(pet.slot_index)
	var index: int = 0
	while index in used:
		index += 1
	return index


func _exit_tree() -> void:
	for pet: Pet in _pets:
		if is_instance_valid(pet):
			pet.queue_free()
	_pets.clear()
