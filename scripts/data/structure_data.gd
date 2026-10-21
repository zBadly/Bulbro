class_name StructureData
extends Resource
## Struktur (GDD 8: Lampenturm). Schaden skaliert mit Technik, nicht mit Schaden-%.
## Ranken (Gewächshauslampe) schießen nicht, sondern halten Gegner in ihrem Radius fest.

enum Kind {
	TURRET, ## Schießt auf das nächste Ziel (Lampenturm, Drohne).
	ROOT, ## Hält Gegner im Radius fest (Lichtranke).
}

@export var id: StringName
@export var kind: Kind = Kind.TURRET
@export var name_key: String = ""
@export var texture: Texture2D
@export var base_damage: float = 0.0
@export var scalings: Dictionary[StringName, float] = {}
## Abklingzeit pro Tier der bauenden Waffe (Index 0 = Tier I); höheres Tier = schneller.
@export var tier_cooldowns: Array[float] = []
@export var range: float = 0.0
@export var projectile_texture: Texture2D
@export var projectile_speed: float = 0.0

@export_group("Ranke")
@export var root_radius: float = 0.0
@export var root_duration: float = 0.0
## Höchstzahl gleichzeitig; beim Überschreiten verschwindet die älteste (0 = unbegrenzt).
@export var max_count: int = 0


func cooldown_for_tier(tier: int) -> float:
	return tier_cooldowns[clampi(tier, 1, tier_cooldowns.size()) - 1]
