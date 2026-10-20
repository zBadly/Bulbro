class_name WeaponData
extends Resource
## Definition einer Waffe mit Werten für Tier I-IV (GDD Abschnitt 8).

enum Kind {
	THRUST, ## Nahkampf, gerader Stoß
	SWING, ## Nahkampf, Bogen
	RANGED, ## Fernkampf mit Projektilen
}

const MIN_TIER: int = 1
const MAX_TIER: int = 4

@export var id: StringName
## Übersetzungsschlüssel des Namens, z. B. WEAPON_FUNKENPISTOLE.
@export var name_key: String = ""
@export var kind: Kind = Kind.THRUST
@export var classes: Array[StringName] = []
@export var texture: Texture2D
## Drehung der Grafik, damit sie bei Rotation 0 nach rechts zeigt.
@export var sprite_rotation_deg: float = 0.0
## Index 0 = Tier I ... Index 3 = Tier IV.
@export var tiers: Array[WeaponTierStats] = []

@export_group("Fernkampf")
@export var projectile_texture: Texture2D
@export var projectile_speed: float = 0.0

@export_group("Besonderheiten")
## Zusätzlicher Grundschaden pro weiterer Waffe derselben Art (Ast).
@export var damage_per_same_weapon: float = 0.0
## Baut zu Beginn jeder Welle diese Struktur (Schraubenzieher -> Lampenturm).
@export var structure: StructureData


func is_melee() -> bool:
	return kind != Kind.RANGED


func get_tier(tier: int) -> WeaponTierStats:
	return tiers[clampi(tier, MIN_TIER, tiers.size()) - 1]
