class_name FreezeEnemiesAction
extends EffectAction
## Lichtblitz (Stroboskop): friert alle Gegner im sichtbaren Bildausschnitt für `duration` Sekunden ein.

@export var duration: float = 0.0


func execute(ctx: EffectContext, _origin: Vector2) -> void:
	var viewport: Viewport = ctx.player.get_viewport()
	var visible: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	Fx.screen_flash(ctx.tree)
	ctx.player.effect_flash()
	for target: Damageable in Hits.alive_targets(ctx.tree):
		var enemy: Enemy = target as Enemy
		if enemy != null and visible.has_point(enemy.global_position):
			enemy.freeze(duration)


func describe() -> String:
	return TextFormat.t("ACTION_FREEZE") % TextFormat.number(duration)
