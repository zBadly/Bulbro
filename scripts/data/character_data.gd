class_name CharacterData
extends Resource
## Spielbarer Charakter (GDD 10): Effekte, Startwaffen und Sonderregeln.
## Gesperrte Charaktere werden über ChallengeData freigeschaltet (data/challenges).

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
## Von Beginn an spielbar (sonst über eine Challenge).
@export var unlocked_by_default: bool = false


func can_use_weapon(weapon: WeaponData) -> bool:
	if no_melee and weapon.is_melee():
		return false
	for weapon_class: StringName in weapon.classes:
		if weapon_class in banned_classes:
			return false
	return true
