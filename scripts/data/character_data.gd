class_name CharacterData
extends Resource
## Spielbarer Charakter (GDD 10): Effekte, Startwaffen und Sonderregeln.
## Gesperrte Charaktere werden über ChallengeData freigeschaltet (data/challenges).

## Code-Animation im Run (siehe Juice): normales Hüpfen oder Schweben mit Flackern (Irrlicht).
enum IdleStyle { BOB, HOVER_FLICKER }

@export var id: StringName
@export var name_key: String = ""
## Spielsprite (72 x 96).
@export var texture: Texture2D
## Porträt für Charakterauswahl und Lexikon (128 x 128, tools/make_portraits.py). Leer = Spielsprite.
@export var portrait: Texture2D
@export var effects: Array[ItemEffect] = []
## Auswahl an Startwaffen (eine wird vor dem Run gewählt).
@export var starting_weapons: Array[WeaponData] = []
@export var weapon_slots: int = 0
@export var preferred_tags: Array[StringName] = []
## Reihenfolge in der Charakterauswahl (GDD-Liste).
@export var order: int = 0
## Lexikon: Übersetzungsschlüssel eines witzigen Satzes (Glühbirnen-Thema).
@export var lore_text: String = ""
## Lexikon: Spielstil-Tipp (Übersetzungsschlüssel, 1-2 Sätze).
@export var tip_key: String = ""

@export_group("Sonderregeln")
## Multiplikator auf Set-Boni einzelner Klassen (Kerze: Primitiv x2).
@export var set_bonus_multiplier: Dictionary[StringName, float] = {}
## Waffenklassen, die nicht getragen werden können.
@export var banned_classes: Array[StringName] = []
@export var no_melee: bool = false

@export_group("Freischaltung")
## Von Beginn an spielbar (sonst über eine Challenge).
@export var unlocked_by_default: bool = false

@export_group("Darstellung")
## Farbe des Spielerlichts; Alpha 0 = Standardfarbe aus der PlayerConfig.
@export var light_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var idle_style: IdleStyle = IdleStyle.BOB
## Zusatzteil, das beim Laufen nachschwingt (Kronleuchter-Kristalle), gleiche Größe wie `texture`.
@export var swing_texture: Texture2D
## Drehpunkt des Zusatzteils in Sprite-Pixeln (von oben links).
@export var swing_pivot: Vector2 = Vector2.ZERO


func get_portrait() -> Texture2D:
	return portrait if portrait != null else texture


func can_use_weapon(weapon: WeaponData) -> bool:
	if no_melee and weapon.is_melee():
		return false
	for weapon_class: StringName in weapon.classes:
		if weapon_class in banned_classes:
			return false
	return true
