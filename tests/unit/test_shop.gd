extends GutTest
## Tests für den Shop (GDD 7): Preise, Reroll, Sperren, Kombinieren, Limits, Bias, Seltenheitsverteilung.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const RARITY: RarityConfig = preload("res://data/config/rarity_config.tres")
const CONFIG: ShopConfig = preload("res://data/config/shop_config.tres")
const DRAWS: int = 10000
const TOLERANCE: float = 0.02

var _shop: Shop


func before_each() -> void:
	GameState.start_run(11)
	_shop = Shop.create_from_registry()


func _ctx(wave: int = 5) -> ShopContext:
	var ctx: ShopContext = ShopContext.new()
	ctx.wave = wave
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = 99
	return ctx


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


# Preise
func test_offer_prices_include_inflation() -> void:
	var ctx: ShopContext = _ctx(5)
	_shop.open_shop(ctx)
	for offer: ShopOffer in _shop.offers:
		var base: int = offer.item.price if offer.item != null else offer.weapon.get_tier(offer.tier).price
		assert_eq(offer.price, Economy.inflated_price(base, 5, 0.0))


func test_price_stat_reduces_prices() -> void:
	var ctx: ShopContext = _ctx(5)
	ctx.item_price_pct = -50.0
	_shop.open_shop(ctx)
	var offer: ShopOffer = _shop.offers[0]
	var base: int = offer.item.price if offer.item != null else offer.weapon.get_tier(offer.tier).price
	assert_eq(offer.price, Economy.inflated_price(base, 5, -50.0))
	assert_lt(offer.price, Economy.inflated_price(base, 5, 0.0))


# Reroll
func test_reroll_price_rises_and_resets_each_shop() -> void:
	var ctx: ShopContext = _ctx(4)
	_shop.open_shop(ctx)
	var first: int = _shop.reroll_price(ctx)
	assert_eq(first, 4 + 2, "Welle + Zuschlag")
	_shop.reroll(ctx)
	assert_eq(_shop.reroll_price(ctx), first + 2)
	_shop.open_shop(ctx)
	assert_eq(_shop.reroll_price(ctx), first, "neuer Shop setzt zurück")


func test_free_rerolls_are_used_first() -> void:
	var ctx: ShopContext = _ctx(4)
	ctx.free_rerolls = 1
	_shop.open_shop(ctx)
	assert_eq(_shop.reroll_price(ctx), 0)
	_shop.reroll(ctx)
	assert_eq(_shop.reroll_price(ctx), 6, "danach normal, Preis nicht erhöht")


func test_buying_all_offers_makes_reroll_free() -> void:
	var ctx: ShopContext = _ctx(4)
	_shop.open_shop(ctx)
	for i in _shop.offers.size():
		_shop.mark_sold(i)
	assert_eq(_shop.reroll_price(ctx), 0)
	_shop.reroll(ctx)
	assert_gt(_shop.reroll_price(ctx), 0, "nur der aktuelle Reroll ist gratis")


# Sperren
func test_locked_offer_keeps_item_and_price_across_waves() -> void:
	_shop.open_shop(_ctx(3))
	_shop.toggle_lock(1)
	var locked: ShopOffer = _shop.offers[1]
	_shop.open_shop(_ctx(9))
	assert_true(locked in _shop.offers, "gesperrtes Angebot bleibt")
	var original_price: int = locked.price
	_shop.reroll(_ctx(9))
	assert_true(locked in _shop.offers)
	assert_eq(locked.price, original_price, "Preis bleibt trotz Inflation")
	assert_eq(_shop.offers.size(), CONFIG.offer_count)


func test_unlocking_lets_offer_be_replaced() -> void:
	_shop.open_shop(_ctx(3))
	_shop.toggle_lock(0)
	var offer: ShopOffer = _shop.offers[0]
	_shop.toggle_lock(0)
	_shop.reroll(_ctx(3))
	assert_false(offer in _shop.offers)


# Limits und Bias
func test_items_at_limit_are_not_offered() -> void:
	var ctx: ShopContext = _ctx(20)
	ctx.luck = 500.0
	ctx.owned_items = {&"kernreaktor": 1, &"wuerfellampe": 3}
	for i in 300:
		var offer: ShopOffer = _shop.generate_offer(ctx, ctx.owned_items.duplicate())
		if offer.item != null:
			assert_ne(offer.item.id, &"kernreaktor")
			assert_ne(offer.item.id, &"wuerfellampe")


func test_class_bias_favors_owned_classes() -> void:
	var ctx: ShopContext = _ctx(5)
	ctx.owned_weapons = [load("res://data/weapons/funkenpistole.tres") as WeaponData]
	var guns: int = 0
	for i in DRAWS:
		if WeaponClasses.GUN in _shop.pick_weapon(ctx).classes:
			guns += 1
	var expected: float = CONFIG.class_bias_chance + (1.0 - CONFIG.class_bias_chance) / _shop.weapons.size()
	assert_almost_eq(float(guns) / DRAWS, expected, TOLERANCE)


# Kombinieren
func test_combine_two_same_tier_into_next_tier() -> void:
	var player: Player = _player()
	var ast: WeaponData = load("res://data/weapons/ast.tres")
	var a: Weapon = player.weapon_slots.add_weapon(ast, 1)
	player.weapon_slots.add_weapon(ast, 1)
	var combined: Weapon = player.weapon_slots.combine(a)
	assert_eq(combined.tier, 2)
	assert_eq(player.weapon_slots.get_weapons().size(), 1)


func test_cannot_combine_different_tiers_or_tier_four() -> void:
	var player: Player = _player()
	var ast: WeaponData = load("res://data/weapons/ast.tres")
	var a: Weapon = player.weapon_slots.add_weapon(ast, 1)
	player.weapon_slots.add_weapon(ast, 2)
	assert_null(player.weapon_slots.combine(a))
	var b: Weapon = player.weapon_slots.add_weapon(ast, 4)
	player.weapon_slots.add_weapon(ast, 4)
	assert_null(player.weapon_slots.combine(b))


func test_buying_with_full_slots_combines_automatically() -> void:
	var player: Player = _player()
	var ast: WeaponData = load("res://data/weapons/ast.tres")
	var fist: WeaponData = load("res://data/weapons/funkenfaust.tres")
	player.weapon_slots.add_weapon(fist, 1)
	for i in player.config.weapon_slots - 1:
		player.weapon_slots.add_weapon(ast, 1)
	assert_true(player.weapon_slots.is_full())
	assert_true(player.weapon_slots.can_accept(fist, 1))
	assert_false(player.weapon_slots.can_accept(fist, 2), "kein Partner auf Tier II")
	var result: Weapon = player.weapon_slots.add_or_combine(fist, 1)
	assert_eq(result.tier, 2)
	assert_eq(player.weapon_slots.count_of(&"funkenfaust"), 1)


# Seltenheitsverteilung (statistisch)
func _distribution(wave: int, luck: float) -> Array[float]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var counts: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i in DRAWS:
		counts[Rarity.roll_tier(wave, luck, RARITY, rng.randf()) - 1] += 1.0
	for i in counts.size():
		counts[i] /= DRAWS
	return counts


func test_shop_one_only_tier_one() -> void:
	assert_eq(_distribution(1, 0.0)[0], 1.0)


func test_tier_unlock_waves() -> void:
	var shop_3: Array[float] = _distribution(3, 0.0)
	assert_gt(shop_3[1], 0.0, "Tier II ab Shop 2")
	assert_eq(shop_3[2], 0.0, "Tier III erst ab Shop 4")
	var shop_7: Array[float] = _distribution(7, 0.0)
	assert_gt(shop_7[2], 0.0)
	assert_eq(shop_7[3], 0.0, "Tier IV erst ab Shop 8")
	assert_gt(_distribution(8, 0.0)[3], 0.0)


func test_late_distribution_matches_caps() -> void:
	var dist: Array[float] = _distribution(20, 0.0)
	assert_almost_eq(dist[1], 0.60, TOLERANCE, "Tier II gedeckelt bei 60 %")
	assert_almost_eq(dist[2], 0.25, TOLERANCE, "Tier III gedeckelt bei 25 %")
	assert_almost_eq(dist[3], Rarity.tier_chance(4, 20, 0.0, RARITY), TOLERANCE)


func test_luck_shifts_distribution_up() -> void:
	var normal: Array[float] = _distribution(5, 0.0)
	var lucky: Array[float] = _distribution(5, 100.0)
	assert_gt(lucky[1] + lucky[2], normal[1] + normal[2])
	assert_lt(lucky[0], normal[0])
