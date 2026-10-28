class_name SurviveLethalEffect
extends ItemEffect
## Fängt tödliche Treffer ab: der Spieler bleibt mit `survive_hp` HP stehen (Reservebatterie: einmal pro Welle, 1 HP).
## Ladungen füllen sich zu Beginn jeder Welle auf.

const CHARGES_KEY: String = "charges"

@export var charges_per_wave: int = 0
@export var survive_hp: float = 0.0


func is_trigger() -> bool:
	return true


func on_wave_started(_ctx: EffectContext, entry: TriggerEntry) -> void:
	entry.timer = 0.0
	entry.state[CHARGES_KEY] = charges_per_wave


func on_lethal_hit(ctx: EffectContext, entry: TriggerEntry) -> bool:
	var charges: int = charges_left(entry)
	if charges <= 0:
		return false
	entry.state[CHARGES_KEY] = charges - 1
	ctx.player.current_hp = minf(survive_hp, ctx.player.get_max_hp())
	return true


## Ohne Wellenstart (Kauf mitten in der Welle per Admin) gelten alle Ladungen als verfügbar.
func charges_left(entry: TriggerEntry) -> int:
	return int(entry.state.get(CHARGES_KEY, charges_per_wave))


func hud_charge(entry: TriggerEntry) -> float:
	return 1.0 if charges_left(entry) > 0 else 0.0


func describe() -> PackedStringArray:
	var key: String = "EFFECT_SURVIVE_LETHAL_ONCE" if charges_per_wave == 1 else "EFFECT_SURVIVE_LETHAL"
	return [TextFormat.t(key) % ([TextFormat.number(survive_hp)] if charges_per_wave == 1 else [charges_per_wave, TextFormat.number(survive_hp)])]
