class_name ShopOffer
extends RefCounted
## Ein Angebot im Shop: Item oder Waffe mit Tier und festem Preis (bleibt beim Sperren erhalten).

var item: ItemData
var weapon: WeaponData
var tier: int = 1
var price: int = 0
var locked: bool = false
var sold: bool = false


func is_weapon() -> bool:
	return weapon != null


func get_modifiers() -> Array[StatModifier]:
	return item.get_modifiers() if item != null else []
