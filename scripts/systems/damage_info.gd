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


static func create(p_amount: int, p_is_crit: bool, p_knockback: float, p_source: Node, p_origin: StringName = &"") -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.amount = p_amount
	info.is_crit = p_is_crit
	info.knockback = p_knockback
	info.source = p_source
	info.origin = p_origin
	return info
