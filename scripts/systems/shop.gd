class_name Shop
extends RefCounted
## Shop-Logik (GDD 7), unabhängig von der UI: Angebote erzeugen, Sperren, Reroll-Preise, Verkauft-Status.
## Sparks werden vom Aufrufer abgezogen; der Shop merkt sich nur seinen Zustand über die Wellen hinweg.

const CONFIG: ShopConfig = preload("res://data/config/shop_config.tres")
const RARITY: RarityConfig = preload("res://data/config/rarity_config.tres")

var items: Array[ItemData] = []
var weapons: Array[WeaponData] = []
var offers: Array[ShopOffer] = []
var rerolls_done: int = 0
var free_rerolls_left: int = 0
## Nach dem Kauf aller Angebote ist der nächste Reroll gratis.
var reroll_is_free: bool = false


static func create_from_registry() -> Shop:
	var shop: Shop = Shop.new()
	for res: Resource in DataRegistry.get_all("items"):
		shop.items.append(res as ItemData)
	for res: Resource in DataRegistry.get_all("weapons"):
		shop.weapons.append(res as WeaponData)
	return shop


## Neuer Shop nach einer Welle: Reroll-Preis zurücksetzen, gesperrte Angebote behalten, Rest neu ziehen.
func open_shop(ctx: ShopContext) -> void:
	rerolls_done = 0
	free_rerolls_left = ctx.free_rerolls
	reroll_is_free = false
	_fill(ctx)


func reroll_price(ctx: ShopContext) -> int:
	if reroll_is_free or free_rerolls_left > 0:
		return 0
	return Economy.reroll_price(ctx.wave, rerolls_done, CONFIG.reroll_increment_factor, ctx.reroll_price_pct)


## Neu würfeln (der Aufrufer hat reroll_price bereits bezahlt).
func reroll(ctx: ShopContext) -> void:
	if reroll_is_free:
		reroll_is_free = false
	elif free_rerolls_left > 0:
		free_rerolls_left -= 1
	else:
		rerolls_done += 1
	_fill(ctx)


func toggle_lock(index: int) -> void:
	var offer: ShopOffer = offers[index]
	if not offer.sold:
		offer.locked = not offer.locked


func mark_sold(index: int) -> void:
	offers[index].sold = true
	offers[index].locked = false
	if offers.all(func(o: ShopOffer) -> bool: return o.sold):
		reroll_is_free = true


func _fill(ctx: ShopContext) -> void:
	var kept: Array[ShopOffer] = []
	for offer: ShopOffer in offers:
		if offer.locked and not offer.sold:
			kept.append(offer)
	var counts: Dictionary[StringName, int] = ctx.owned_items.duplicate()
	for offer: ShopOffer in kept:
		if offer.item != null:
			counts[offer.item.id] = counts.get(offer.item.id, 0) + 1
	offers = kept
	while offers.size() < CONFIG.offer_count:
		var offer: ShopOffer = generate_offer(ctx, counts)
		if offer.item != null:
			counts[offer.item.id] = counts.get(offer.item.id, 0) + 1
		offers.append(offer)


## Ein zufälliges Angebot. `counts` enthält Besitz plus bereits angebotene Items (für Limits).
func generate_offer(ctx: ShopContext, counts: Dictionary[StringName, int]) -> ShopOffer:
	var rng: RandomNumberGenerator = ctx.rng
	var offer: ShopOffer = ShopOffer.new()
	offer.tier = Rarity.roll_tier(ctx.wave, ctx.luck, RARITY, rng.randf())
	if rng.randf() >= CONFIG.weapon_offer_chance:
		var item: ItemData = Loot.pick_item(items, offer.tier, counts, ctx.preferred_tags, CONFIG.preferred_tag_weight, rng)
		if item != null:
			offer.item = item
			offer.tier = item.tier
			offer.price = Economy.inflated_price(item.price, ctx.wave, ctx.item_price_pct)
			return offer
	offer.weapon = pick_weapon(ctx)
	offer.price = Economy.inflated_price(offer.weapon.get_tier(offer.tier).price, ctx.wave, ctx.item_price_pct)
	return offer


## 15 % der Waffenangebote stammen aus Klassen, die der Spieler bereits besitzt.
func pick_weapon(ctx: ShopContext) -> WeaponData:
	var rng: RandomNumberGenerator = ctx.rng
	var pool: Array[WeaponData] = weapons
	var classes: Array[StringName] = ctx.owned_classes()
	if not classes.is_empty() and rng.randf() < CONFIG.class_bias_chance:
		var matching: Array[WeaponData] = []
		for weapon: WeaponData in weapons:
			for weapon_class: StringName in weapon.classes:
				if weapon_class in classes:
					matching.append(weapon)
					break
		if not matching.is_empty():
			pool = matching
	return pool[rng.randi_range(0, pool.size() - 1)]
