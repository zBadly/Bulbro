class_name CharacterData
extends Resource
## Spielbarer Charakter (GDD 10): Effekte, Startwaffen, Sonderregeln und Freischaltbedingung.

enum Unlock {
	START, ## von Beginn an verfügbar
	STRUCTURES, ## gleichzeitig so viele Strukturen besitzen
	TOTAL_SPARKS, ## über alle Runs so viele Funken gesammelt
	DISTINCT_WEAPONS, ## so viele verschiedene Waffen gleichzeitig
	DAMAGE_PCT, ## Schaden-% in einem Run erreicht
	HEALED, ## so viele HP in einem Run geheilt
	SPEED_PCT, ## Tempo-% in einem Run erreicht
	WIN_PRIMITIVE_ONLY, ## Run nur mit Primitiv-Waffen gewinnen
}

@export var id: StringName
@export var name_key: String = ""
@export var texture: Texture2D
@export var effects: Array[ItemEffect] = []
## Auswahl an Startwaffen (eine wird vor dem Run gewählt).
@export var starting_weapons: Array[WeaponData] = []
@export var weapon_slots: int = 0
@export var preferred_tags: Array[StringName] = []
## Reihenfolge in der Charakterauswahl (GDD-Liste).
@export var order: int = 0

@export_group("Sonderregeln")
## Multiplikator auf Set-Boni einzelner Klassen (Kerze: Primitiv x2).
@export var set_bonus_multiplier: Dictionary[StringName, float] = {}
## Waffenklassen, die nicht getragen werden können.
@export var banned_classes: Array[StringName] = []
@export var no_melee: bool = false

@export_group("Freischaltung")
@export var unlock: Unlock = Unlock.START
@export var unlock_value: float = 0.0
## Item, das ein Sieg mit diesem Charakter für den Shop freischaltet (optional).
@export var win_unlocks_item: ItemData


func can_use_weapon(weapon: WeaponData) -> bool:
	if no_melee and weapon.is_melee():
		return false
	for weapon_class: StringName in weapon.classes:
		if weapon_class in banned_classes:
			return false
	return true
