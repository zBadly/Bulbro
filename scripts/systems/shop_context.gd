class_name ShopContext
extends RefCounted
## Alles, was der Shop über den aktuellen Run wissen muss. Wird vom Shop-Bildschirm aus Spieler und GameState gefüllt.

var wave: int = 1
var luck: float = 0.0
var item_price_pct: float = 0.0
var reroll_price_pct: float = 0.0
var free_rerolls: int = 0
var owned_items: Dictionary[StringName, int] = {}
var owned_weapons: Array[WeaponData] = []
var preferred_tags: Array[StringName] = []
var rng: RandomNumberGenerator


static func from_run(player: Player) -> ShopContext:
	var ctx: ShopContext = ShopContext.new()
	ctx.wave = GameState.current_wave
	ctx.luck = player.stats.get_stat(Stats.LUCK)
	ctx.item_price_pct = player.stats.get_stat(Stats.ITEM_PRICE_PCT)
	ctx.reroll_price_pct = player.stats.get_stat(Stats.REROLL_PRICE_PCT)
	ctx.free_rerolls = roundi(player.stats.get_stat(Stats.FREE_REROLLS))
	ctx.owned_items = GameState.item_counts()
	for weapon: Weapon in player.weapon_slots.get_weapons():
		ctx.owned_weapons.append(weapon.data)
	ctx.preferred_tags = GameState.preferred_tags
	ctx.rng = GameState.rng
	return ctx


func owned_classes() -> Array[StringName]:
	var classes: Array[StringName] = []
	for weapon: WeaponData in owned_weapons:
		for weapon_class: StringName in weapon.classes:
			if weapon_class not in classes:
				classes.append(weapon_class)
	return classes
