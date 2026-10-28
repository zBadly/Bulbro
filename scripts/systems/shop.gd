class_name Shop
extends RefCounted
## Shop-Logik (GDD 7), unabhängig von der UI: Angebote erzeugen, Sperren, Reroll-Preise, Verkauft-Status.
## Sparks werden vom Aufrufer abgezogen; der Shop merkt sich nur seinen Zustand über die Wellen hinweg.

const CONFIG: ShopConfig = preload("res://data/config/shop_config.tres")
const RARITY: RarityConfig = preload("res://data/config/rarity_config.tres")
const PETS: PetConfig = preload("res://data/config/pet_config.tres")

var items: Array[ItemData] = []
var weapons: Array[WeaponData] = []
var pets: Array[PetData] = []
var offers: Array[ShopOffer] = []
var rerolls_done: int = 0
var free_rerolls_left: int = 0
## Nach dem Kauf aller Angebote ist der nächste Reroll gratis.
var reroll_is_free: bool = false
## Nach dem Laden eines gespeicherten Runs: beim nächsten open_shop() nichts neu ziehen.
var keep_offers_once: bool = false


static func create_from_registry() -> Shop:
	var shop: Shop = Shop.new()
	var all_items: Array[ItemData] = []
	for res: Resource in DataRegistry.get_all("items"):
		all_items.append(res as ItemData)
	shop.items = Unlocks.unlocked_items(all_items)
	for res: Resource in DataRegistry.get_all("weapons"):
		shop.weapons.append(res as WeaponData)
	for res: Resource in DataRegistry.get_all("pets"):
		shop.pets.append(res as PetData)
	return shop


## Neuer Shop nach einer Welle: Reroll-Preis zurücksetzen, gesperrte Angebote behalten, Rest neu ziehen.
func open_shop(ctx: ShopContext) -> void:
	if keep_offers_once:
		keep_offers_once = false
		return
	rerolls_done = 0
	free_rerolls_left = ctx.free_rerolls
	reroll_is_free = false
	_fill(ctx)


## Speicherformat für "Run fortsetzen".
func to_dict() -> Dictionary:
	var list: Array = []
	for offer: ShopOffer in offers:
		list.append({"item": String(offer.item.id) if offer.item != null else "",
			"weapon": String(offer.weapon.id) if offer.weapon != null else "",
			"pet": String(offer.pet.id) if offer.pet != null else "",
			"tier": offer.tier, "price": offer.price, "locked": offer.locked, "sold": offer.sold})
	return {"offers": list, "rerolls_done": rerolls_done, "free_rerolls_left": free_rerolls_left, "reroll_is_free": reroll_is_free}


## Stellt Angebote wieder her; der nächste open_shop() behält sie unverändert.
func load_dict(data: Dictionary) -> void:
	offers.clear()
	for entry: Dictionary in data.get("offers", []):
		var offer: ShopOffer = ShopOffer.new()
		offer.item = RunSave.find("items", entry["item"]) as ItemData if entry["item"] != "" else null
		offer.weapon = RunSave.find("weapons", entry["weapon"]) as WeaponData if entry["weapon"] != "" else null
		var pet_id: String = String(entry.get("pet", ""))
		offer.pet = RunSave.find("pets", pet_id) as PetData if pet_id != "" else null
		offer.tier = int(entry["tier"])
		offer.price = int(entry["price"])
		offer.locked = bool(entry["locked"])
		offer.sold = bool(entry["sold"])
		offers.append(offer)
	rerolls_done = int(data.get("rerolls_done", 0))
	free_rerolls_left = int(data.get("free_rerolls_left", 0))
	reroll_is_free = bool(data.get("reroll_is_free", false))
	keep_offers_once = true


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


## Admin: ein bestimmtes Item, eine Waffe oder einen Begleiter in einen Angebotsplatz legen (gesperrt, bleibt bis zum Kauf).
func place_offer(index: int, item: ItemData, weapon: WeaponData, tier: int, ctx: ShopContext, pet: PetData = null) -> void:
	var offer: ShopOffer = ShopOffer.new()
	offer.item = item
	offer.weapon = weapon
	offer.pet = pet
	offer.tier = item.tier if item != null else tier
	var base_price: int = item.price if item != null else 0
	if weapon != null:
		base_price = weapon.get_tier(tier).price
	elif pet != null:
		base_price = pet.get_tier(tier).price
	offer.price = Economy.inflated_price(base_price, ctx.wave, ctx.item_price_pct)
	offer.locked = true
	while offers.size() <= index:
		offers.append(generate_offer(ctx, {}))
	offers[index] = offer


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
	var has_unique: bool = kept.any(func(o: ShopOffer) -> bool: return o.item != null and o.item.is_unique())
	while offers.size() < CONFIG.offer_count:
		var offer: ShopOffer = null
		if not has_unique and ctx.wave >= CONFIG.unique_min_wave and ctx.rng.randf() < unique_chance(ctx.luck):
			offer = generate_unique_offer(ctx, counts)
			has_unique = offer != null
		if offer == null:
			offer = generate_offer(ctx, counts)
		if offer.item != null:
			counts[offer.item.id] = counts.get(offer.item.id, 0) + 1
		offers.append(offer)


## Chance je Angebotsplatz auf ein einzigartiges Item (ab CONFIG.unique_min_wave); Glück erhöht sie leicht.
static func unique_chance(luck: float) -> float:
	return clampf(CONFIG.unique_chance * (1.0 + luck / Rarity.PERCENT * CONFIG.unique_luck_factor), 0.0, CONFIG.unique_max_chance)


## Ein einzigartiges Item, das weder besessen noch schon angeboten ist; null, wenn keins mehr übrig ist.
func generate_unique_offer(ctx: ShopContext, counts: Dictionary[StringName, int]) -> ShopOffer:
	var pool: Array[ItemData] = []
	for item: ItemData in items:
		if item.is_unique() and not item.is_at_limit(counts.get(item.id, 0)) and counts.get(item.id, 0) == 0:
			pool.append(item)
	if pool.is_empty():
		return null
	var offer: ShopOffer = ShopOffer.new()
	offer.item = pool[ctx.rng.randi_range(0, pool.size() - 1)]
	offer.tier = offer.item.tier
	offer.price = Economy.inflated_price(offer.item.price, ctx.wave, ctx.item_price_pct)
	return offer


## Ein zufälliges Angebot. `counts` enthält Besitz plus bereits angebotene Items (für Limits).
func generate_offer(ctx: ShopContext, counts: Dictionary[StringName, int]) -> ShopOffer:
	var rng: RandomNumberGenerator = ctx.rng
	var offer: ShopOffer = ShopOffer.new()
	offer.tier = Rarity.roll_tier(ctx.wave, ctx.luck, RARITY, rng.randf())
	var kind_roll: float = rng.randf()
	# Begleiter nehmen ihren Anteil vom Item-Anteil, damit der Waffenanteil gleich bleibt.
	if kind_roll >= CONFIG.weapon_offer_chance and kind_roll < CONFIG.weapon_offer_chance + PETS.offer_chance and not pets.is_empty():
		offer.pet = pick_pet(ctx)
		offer.price = Economy.inflated_price(offer.pet.get_tier(offer.tier).price, ctx.wave, ctx.item_price_pct)
		return offer
	if kind_roll >= CONFIG.weapon_offer_chance:
		var item: ItemData = Loot.pick_item(items, offer.tier, counts, ctx.preferred_tags, CONFIG.preferred_tag_weight, rng)
		if item != null:
			offer.item = item
			offer.tier = item.tier
			offer.price = Economy.inflated_price(item.price, ctx.wave, ctx.item_price_pct)
			return offer
	offer.weapon = pick_weapon(ctx)
	offer.price = Economy.inflated_price(offer.weapon.get_tier(offer.tier).price, ctx.wave, ctx.item_price_pct)
	return offer


## Zufälliger Begleiter; solche mit bevorzugten Tags des Charakters zählen wie bei Items mehrfach.
func pick_pet(ctx: ShopContext) -> PetData:
	var weights: Array[float] = []
	var total: float = 0.0
	for pet: PetData in pets:
		var weight: float = 1.0
		for tag: StringName in pet.tags:
			if tag in ctx.preferred_tags:
				weight = CONFIG.preferred_tag_weight
				break
		weights.append(weight)
		total += weight
	var roll: float = ctx.rng.randf() * total
	for i in pets.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pets[i]
	return pets[pets.size() - 1]


## 15 % der Waffenangebote stammen aus Klassen, die der Spieler bereits besitzt.
func pick_weapon(ctx: ShopContext) -> WeaponData:
	var rng: RandomNumberGenerator = ctx.rng
	var pool: Array[WeaponData] = []
	pool.assign(weapons.filter(ctx.weapon_allowed) if ctx.weapon_allowed.is_valid() else weapons)
	var classes: Array[StringName] = ctx.owned_classes()
	if not classes.is_empty() and rng.randf() < CONFIG.class_bias_chance:
		var matching: Array[WeaponData] = []
		for weapon: WeaponData in pool:
			for weapon_class: StringName in weapon.classes:
				if weapon_class in classes:
					matching.append(weapon)
					break
		if not matching.is_empty():
			pool = matching
	return pool[rng.randi_range(0, pool.size() - 1)]
