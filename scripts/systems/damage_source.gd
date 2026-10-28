class_name DamageSource
extends RefCounted
## Herkunft eines Treffers als Schlüssel "art/id" (z. B. "weapon/funkenpistole", "item/supernova").
## Damit zählt RunStats Kills und Schaden je Waffe, Item, Charakter-Effekt, Verbündete, Struktur und Begleiter.

const WEAPON: String = "weapon"
const ITEM: String = "item"
const CHARACTER: String = "character"
const ALLY: String = "ally"
const STRUCTURE: String = "structure"
const PET: String = "pet"
const SEPARATOR: String = "/"


static func weapon(id: StringName) -> StringName:
	return make(WEAPON, id)


static func item(id: StringName) -> StringName:
	return make(ITEM, id)


static func character(id: StringName) -> StringName:
	return make(CHARACTER, id)


static func ally() -> StringName:
	return StringName(ALLY)


static func structure(id: StringName) -> StringName:
	return make(STRUCTURE, id)


static func pet(id: StringName) -> StringName:
	return make(PET, id)


static func make(kind: String, id: StringName) -> StringName:
	return StringName(kind + SEPARATOR + String(id))


## Art der Herkunft ("weapon", "item", ...); leer ohne Herkunft.
static func kind_of(origin: StringName) -> String:
	return String(origin).get_slice(SEPARATOR, 0)


## ID hinter der Art (leer bei Verbündeten).
static func id_of(origin: StringName) -> StringName:
	var text: String = String(origin)
	var index: int = text.find(SEPARATOR)
	return StringName(text.substr(index + 1)) if index >= 0 else &""
