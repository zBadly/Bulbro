class_name BurnOnHitEffect
extends ItemEffect
## Mit `chance` pro Treffer: Brand auf dem Ziel (Zündkerze). Schaden mit Skalierung, Schaden-% und Brandschaden-%.

@export_range(0.0, 1.0) var chance: float = 0.0
@export var base_damage: float = 0.0
@export var scalings: Dictionary[StringName, float] = {}
@export var ticks: int = 0


func is_trigger() -> bool:
	return true


func on_enemy_hit(ctx: EffectContext, _entry: TriggerEntry, target: Damageable, _info: DamageInfo) -> void:
	var enemy: Enemy = target as Enemy
	if enemy == null or not enemy.is_alive() or ctx.rng.randf() >= chance:
		return
	var damage: float = CombatMath.burn_damage(ctx.effect_damage(base_damage, scalings), ctx.player.stats.get_stat(Stats.BURN_DMG_PCT))
	enemy.apply_burn(damage, ticks, ctx.player)


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_BURN_ON_HIT") % [roundi(chance * 100.0), EffectAction.damage_text(base_damage, scalings), ticks]]
