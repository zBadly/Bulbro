class_name ShopOffer
extends RefCounted
## Ein Angebot im Shop: Item, Waffe oder Begleiter mit Tier und festem Preis (bleibt beim Sperren erhalten).

var item: ItemData
var weapon: WeaponData
var pet: PetData
var tier: int = 1
var price: int = 0
var locked: bool = false
var sold: bool = false


func is_weapon() -> bool:
	return weapon != null


func is_pet() -> bool:
	return pet != null


func get_modifiers() -> Array[StatModifier]:
	# Kein Ternär mit "[]": das Literal wäre ungetypt und die Zuweisung an Array[StatModifier] schlüge fehl.
	if item == null:
		return []
	return item.get_modifiers()
