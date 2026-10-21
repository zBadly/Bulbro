class_name MirrorCloneEffect
extends ItemEffect
## Spiegelkugel: Ein Spiegelbild folgt dem Spieler und trägt Kopien aller Waffen mit `damage_factor` Schaden.
## Wird zu Wellenbeginn mit den aktuellen Waffen erzeugt und am Wellenende entfernt.

const CLONE_KEY: String = "clone"

@export var damage_factor: float = 1.0


func is_trigger() -> bool:
	return true


func on_wave_started(ctx: EffectContext, entry: TriggerEntry) -> void:
	super.on_wave_started(ctx, entry)
	_remove(entry)
	var clone: MirrorClone = MirrorClone.new()
	ctx.player.get_parent().add_child(clone)
	clone.setup(ctx.player, damage_factor)
	entry.state[CLONE_KEY] = clone


func on_wave_ended(_ctx: EffectContext, entry: TriggerEntry) -> void:
	_remove(entry)


func _remove(entry: TriggerEntry) -> void:
	var clone: Variant = entry.state.get(CLONE_KEY)
	if is_instance_valid(clone):
		(clone as Node).queue_free()
	entry.state.erase(CLONE_KEY)


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_MIRROR_CLONE") % roundi(damage_factor * 100.0)]
