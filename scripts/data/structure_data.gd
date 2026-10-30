class_name StructureData
extends Resource
## Struktur (GDD 8: Lampenturm). Schaden skaliert mit Technik, nicht mit Schaden-%.
## Ranken (Gewächshauslampe) schießen nicht, sondern halten Gegner in ihrem Radius fest.
## Türme aus Items (Paket 8): Flammen-, Frost-, Heilturm und Stolperdraht. Abklingzeiten werden mit dem
## Struktur-Angriffstempo kürzer, Schaden, Heilung und Aura-Radius wachsen mit Technik.

enum Kind {
	TURRET, ## Schießt auf das nächste Ziel (Lampenturm, Drohne).
	ROOT, ## Hält Gegner im Radius fest (Lichtranke).
	FLAME, ## Flammenstrahl auf das nächste Ziel, trifft alles auf dem Strahl und setzt Brand.
	FROST, ## Verlangsamt alle Gegner in der Aura.
	HEAL, ## Heilt den Spieler, solange er in der Aura steht.
	MINE_LAYER, ## Legt in Abständen Minen in seiner Nähe.
}

const PERCENT: float = 100.0

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

@export_group("Aura")
## Frost- und Heilturm: Radius der Aura, wächst um `aura_radius_per_engineering` px pro Punkt Technik.
@export var aura_radius: float = 0.0
@export var aura_radius_per_engineering: float = 0.0
@export var aura_color: Color = Color.WHITE

@export_group("Flamme")
## Breite des Flammenstrahls (px); getroffen wird alles, was so nah an der Strahllinie steht.
@export var beam_width: float = 0.0
## Höchstens so viele Treffer pro Strahl, die nächsten zur Mündung zuerst (Übersicht und Performance im Gedränge).
@export var beam_max_targets: int = 0
@export var burn_damage: float = 0.0
@export var burn_scalings: Dictionary[StringName, float] = {}
@export var burn_ticks: int = 0

@export_group("Frost")
@export var slow_pct: float = 0.0
## Dauer jeder Verlangsamung; etwas länger als die Abklingzeit, damit sie im Radius nicht abreißt.
@export var slow_duration: float = 0.0

@export_group("Heilung")
@export var heal_amount: float = 0.0
@export var heal_scalings: Dictionary[StringName, float] = {}

@export_group("Mine")
@export var mine: ExplosionAction
@export var mine_texture: Texture2D
## Minen landen zufällig bis zu diesem Abstand (px) um den Turm.
@export var mine_spread: float = 0.0
## Scharf nach dieser Zeit (s), dann löst ein Gegner im Radius `mine_trigger_radius` sie aus.
@export var mine_arm_time: float = 0.0
@export var mine_trigger_radius: float = 0.0


func cooldown_for_tier(tier: int) -> float:
	return tier_cooldowns[clampi(tier, 1, tier_cooldowns.size()) - 1]


## Abklingzeit mit Struktur-Angriffstempo.
func cooldown(tier: int, stats: StatSystem) -> float:
	return CombatMath.attack_cooldown(cooldown_for_tier(tier), stats.get_stat(Stats.STRUCTURE_ATTACK_SPEED_PCT))


## Treffer- bzw. Strahlschaden: Basis + Technik, ohne Schaden-%.
func damage(stats: StatSystem) -> int:
	return CombatMath.weapon_damage(base_damage, CombatMath.scaling_bonus(scalings, stats), 0.0, 1.0)


## Brandschaden pro Tick (Flammenturm), vor Brandschaden-%.
func burn_tick(stats: StatSystem) -> float:
	return burn_damage + CombatMath.scaling_bonus(burn_scalings, stats)


## Geheilte HP pro Auslösung (Heilturm), abgerundet, mindestens die Basis.
func heal(stats: StatSystem) -> int:
	return maxi(roundi(heal_amount), floori(heal_amount + CombatMath.scaling_bonus(heal_scalings, stats)))


func aura(stats: StatSystem) -> float:
	return aura_radius + aura_radius_per_engineering * maxf(0.0, stats.get_stat(Stats.ENGINEERING))


## Schaden einer Mine vor Explosionsschaden-% (wie ExplosionAction ohne Schaden-%).
func mine_damage(stats: StatSystem) -> int:
	return CombatMath.weapon_damage(mine.base_damage, CombatMath.scaling_bonus(mine.scalings, stats), 0.0, 1.0)


## Turm im Sinne der Obergrenze (Ranken haben ihre eigene Höchstzahl).
func is_tower() -> bool:
	return kind != Kind.ROOT


## Beschreibung für Tooltips und Lexikon (BBCode): Wirkung mit Basiswerten und Skalierung.
func describe() -> PackedStringArray:
	var cd: String = TextFormat.number(cooldown_for_tier(1)) if not tier_cooldowns.is_empty() else ""
	match kind:
		Kind.TURRET:
			return [TextFormat.t("TOWER_DESC_TURRET") % [EffectAction.damage_text(base_damage, scalings), cd, TextFormat.number(range)]]
		Kind.FLAME:
			return [TextFormat.t("TOWER_DESC_FLAME") % [EffectAction.damage_text(base_damage, scalings), beam_max_targets, cd, TextFormat.number(range)],
				TextFormat.t("TOWER_DESC_BURN") % [EffectAction.damage_text(burn_damage, burn_scalings), burn_ticks]]
		Kind.FROST:
			return [TextFormat.t("TOWER_DESC_FROST") % [roundi(slow_pct), _radius_text()]]
		Kind.HEAL:
			return [TextFormat.t("TOWER_DESC_HEAL") % [EffectAction.damage_text(heal_amount, heal_scalings), cd, _radius_text()]]
		Kind.MINE_LAYER:
			return [TextFormat.t("TOWER_DESC_MINE") % [cd, EffectAction.damage_text(mine.base_damage, mine.scalings)]]
		Kind.ROOT:
			return [TextFormat.t("TOWER_DESC_ROOT") % [TextFormat.number(root_radius), TextFormat.number(root_duration)]]
	return []


## "160 px (+1 px pro Technik)".
func _radius_text() -> String:
	if aura_radius_per_engineering <= 0.0:
		return TextFormat.number(aura_radius)
	return TextFormat.t("TOWER_RADIUS_SCALING") % [TextFormat.number(aura_radius), TextFormat.number(aura_radius_per_engineering),
		TextFormat.t(Stats.label_key(Stats.ENGINEERING))]
