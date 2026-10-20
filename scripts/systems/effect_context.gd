class_name EffectContext
extends RefCounted
## Was Effekte und Aktionen zur Laufzeit brauchen: Spieler, Szenenbaum und Run-Zufall.

var player: Player
var tree: SceneTree
var rng: RandomNumberGenerator


static func create(p_player: Player) -> EffectContext:
	var ctx: EffectContext = EffectContext.new()
	ctx.player = p_player
	ctx.tree = p_player.get_tree()
	ctx.rng = p_player.rng
	return ctx


## Schaden einer Item-Aktion: Basis + Skalierung, mit Schaden-%. Mindestens 1.
func effect_damage(base_damage: float, scalings: Dictionary[StringName, float]) -> int:
	var stats: StatSystem = player.stats
	return CombatMath.weapon_damage(base_damage, CombatMath.scaling_bonus(scalings, stats), stats.get_stat(Stats.DAMAGE_PCT), 1.0)
