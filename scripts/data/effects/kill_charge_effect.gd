class_name KillChargeEffect
extends ItemEffect
## Lädt sich durch Kills auf: nach je `kills_needed` Kills (alle Quellen) verursacht der nächste Angriff jeder
## getragenen Waffe `damage_factor`-fachen Schaden (Kondensator: 15 Kills, doppelter Schaden).
## Der Zusatzschaden zählt in der Run-Statistik für das Item, ebenso Kills, die erst der Zusatzschaden ermöglicht.

const KILLS_KEY: String = "kills"
## Instanz-IDs der Waffen, deren nächster Angriff verstärkt ist.
const CHARGED_KEY: String = "charged"

@export var kills_needed: int = 0
@export var damage_factor: float = 1.0


func is_trigger() -> bool:
	return true


func on_wave_started(_ctx: EffectContext, entry: TriggerEntry) -> void:
	entry.timer = 0.0


func on_enemy_killed(ctx: EffectContext, entry: TriggerEntry, _position: Vector2, _data: EnemyData, _info: DamageInfo) -> void:
	var kills: int = int(entry.state.get(KILLS_KEY, 0)) + 1
	if kills >= kills_needed:
		kills = 0
		var charged: Dictionary = {}
		for weapon: Weapon in ctx.player.weapon_slots.get_weapons():
			charged[weapon.get_instance_id()] = true
		entry.state[CHARGED_KEY] = charged
	entry.state[KILLS_KEY] = kills


func on_weapon_attack(ctx: EffectContext, entry: TriggerEntry, weapon: Weapon, _target: Damageable) -> void:
	var charged: Dictionary = entry.state.get(CHARGED_KEY, {})
	if charged.erase(weapon.get_instance_id()):
		weapon.charge_next_attack(damage_factor, ctx.origin)


func is_charged(entry: TriggerEntry) -> bool:
	return not (entry.state.get(CHARGED_KEY, {}) as Dictionary).is_empty()


## Voll (1), solange noch Waffen einen verstärkten Angriff haben, sonst Fortschritt der Kills.
func hud_charge(entry: TriggerEntry) -> float:
	if is_charged(entry):
		return 1.0
	return float(entry.state.get(KILLS_KEY, 0)) / maxf(1.0, kills_needed)


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_KILL_CHARGE") % [kills_needed, TextFormat.number(damage_factor)]]
