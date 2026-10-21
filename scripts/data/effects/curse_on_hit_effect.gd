class_name CurseOnHitEffect
extends ItemEffect
## Treffer verfluchen Gegner (Schwarzlicht): Schaden pro Sekunde und mehr erlittener Schaden, stapelbar.

@export_range(0.0, 1.0) var chance: float = 1.0
@export var duration: float = 0.0
@export var damage_per_second: float = 0.0
## Zusätzlich erlittener Schaden in % pro Stapel.
@export var damage_taken_pct: float = 0.0
@export var max_stacks: int = 1


func is_trigger() -> bool:
	return true


func on_enemy_hit(ctx: EffectContext, _entry: TriggerEntry, target: Damageable, _info: DamageInfo) -> void:
	var enemy: Enemy = target as Enemy
	if enemy == null or not enemy.is_alive():
		return
	if chance < 1.0 and ctx.rng.randf() >= chance:
		return
	enemy.apply_curse(damage_per_second, damage_taken_pct, duration, max_stacks)


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_CURSE_ON_HIT") % [TextFormat.number(duration), TextFormat.number(damage_per_second),
		roundi(damage_taken_pct), max_stacks]]
