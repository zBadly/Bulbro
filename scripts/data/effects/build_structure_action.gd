class_name BuildStructureAction
extends EffectAction
## Baut eine Struktur in der Nähe des Spielers (Gewächshauslampe: Lichtranke). Die Arena erzeugt sie.

@export var structure: StructureData
@export var tier: int = 1
## Abstand zum Spieler (zufällig zwischen der Hälfte und dem vollen Wert).
@export var distance: float = 0.0


func execute(ctx: EffectContext, _origin: Vector2) -> void:
	var offset: Vector2 = Vector2.from_angle(ctx.rng.randf() * TAU) * ctx.rng.randf_range(0.5, 1.0) * distance
	Events.structure_requested.emit(structure, tier, ctx.player.global_position + offset)


func describe() -> String:
	return TextFormat.t("ACTION_BUILD_STRUCTURE") % TextFormat.t(structure.name_key)
