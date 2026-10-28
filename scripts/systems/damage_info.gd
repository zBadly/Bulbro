class_name DamageInfo
extends RefCounted
## Ein Treffer gegen einen Gegner: fertig berechneter Schaden plus Rückstoß.

var amount: int = 0
var is_crit: bool = false
## Rückstoß-Wert der Waffe (wird vom Ziel in eine Geschwindigkeit umgerechnet).
var knockback: float = 0.0
var knockback_dir: Vector2 = Vector2.ZERO
var source: Node
## Herkunft für die Run-Statistik (DamageSource, z. B. "weapon/funkenpistole"); leer = nicht gezählt.
var origin: StringName = &""
## Zusatzwirkungen des Treffers (von der Waffe gesetzt).
var burn_damage: float = 0.0
var burn_ticks: int = 0
var burn_chance: float = 1.0
var root_chance: float = 0.0
var root_duration: float = 0.0
var heal_on_hit_chance: float = 0.0
var spark_on_kill_chance: float = 0.0
## Brand-Tick (für Brand-Kills und damit Treffer-Effekte nicht erneut auslösen).
var is_burn: bool = false
## Zusätzliche Seelen bei einem Kill mit diesem Treffer (Irrlicht).
var extra_souls: int = 0
## Verstärkter Angriff (Kondensator): dieser Anteil des Schadens zählt für `bonus_origin` statt für `origin`.
var bonus_origin: StringName = &""
var bonus_share: float = 0.0


static func create(p_amount: int, p_is_crit: bool, p_knockback: float, p_source: Node, p_origin: StringName = &"") -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.amount = p_amount
	info.is_crit = p_is_crit
	info.knockback = p_knockback
	info.source = p_source
	info.origin = p_origin
	return info


## Kopie mit anderer Herkunft (Kill durch den Zusatzschaden eines verstärkten Angriffs).
func with_origin(p_origin: StringName) -> DamageInfo:
	var copy: DamageInfo = DamageInfo.create(amount, is_crit, knockback, source, p_origin)
	copy.knockback_dir = knockback_dir
	copy.burn_damage = burn_damage
	copy.burn_ticks = burn_ticks
	copy.burn_chance = burn_chance
	copy.root_chance = root_chance
	copy.root_duration = root_duration
	copy.heal_on_hit_chance = heal_on_hit_chance
	copy.spark_on_kill_chance = spark_on_kill_chance
	copy.is_burn = is_burn
	copy.extra_souls = extra_souls
	return copy
