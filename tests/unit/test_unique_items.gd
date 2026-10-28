extends GutTest
## Phase 15, Paket 8: Einzigartige Items (Seltenheit "Einzigartig" = Tier 5). Tier 5 darf nirgends wie ein
## höheres Tier IV behandelt werden: nie in Kartons und Level-ups, eigener Shop-Wurf ab Welle 5, höchstens eins
## pro Angebot, Anzeige "Einzigartig". Dazu die neuen Effekttypen (Stat pro Stat live, Bonus unter X % HP,
## tödlichen Treffer überleben, nach N Kills).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const RARITY: RarityConfig = preload("res://data/config/rarity_config.tres")
const CONFIG: ShopConfig = preload("res://data/config/shop_config.tres")
const UNIQUE_IDS: Array[String] = ["panzerglas", "schwungrad", "gluecksfassung", "hochspannungsspeicher", "gleichrichter",
	"leuchtturm", "reservebatterie", "thermosicherung", "kondensator", "sparlampe"]
const GOLD: Color = Color("#F5A623")
const DRAWS: int = 4000
const SHORT_DRAWS: int = 1000


func before_each() -> void:
	GameState.start_run(23)
	GameState.phase = GameState.Phase.WAVE


func _item(id: String) -> ItemData:
	return load("res://data/items/%s.tres" % id)


func _uniques() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for res: Resource in DataRegistry.get_all("items"):
		if (res as ItemData).is_unique():
			result.append(res)
	return result


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.rng = RandomNumberGenerator.new()
	add_child_autofree(player)
	return player


func _give(player: Player, id: String) -> ItemData:
	var item: ItemData = _item(id)
	GameState.add_item(item)
	player.apply_item(item)
	return item


func _ctx(wave: int, seed_value: int = 5) -> ShopContext:
	var ctx: ShopContext = ShopContext.new()
	ctx.wave = wave
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = seed_value
	return ctx


func _count_uniques(offers: Array[ShopOffer]) -> int:
	return offers.filter(func(o: ShopOffer) -> bool: return o.item != null and o.item.is_unique()).size()


# --- Daten und Anzeige ---

func test_ten_uniques_with_tier_five_and_limit_one() -> void:
	var ids: Array[String] = []
	for item: ItemData in _uniques():
		ids.append(String(item.id))
		assert_eq(item.tier, ItemData.UNIQUE_TIER)
		assert_eq(item.limit, 1, String(item.id))
		assert_true(TranslationServer.translate(item.lore_text) != item.lore_text, "lore_text übersetzt")
	ids.sort()
	var expected: Array[String] = UNIQUE_IDS.duplicate()
	expected.sort()
	assert_eq(ids, expected)


func test_tier_five_shows_unique_name_and_gold() -> void:
	assert_eq(TextFormat.tier_name(ItemData.UNIQUE_TIER), "Einzigartig")
	assert_false(TextFormat.tier_name(ItemData.UNIQUE_TIER).contains("Tier"))
	assert_eq(UiStyle.tier_color(ItemData.UNIQUE_TIER), GOLD)
	assert_eq(UiStyle.tier_color(4), Color("#E74C3C"), "Tier IV bleibt rot")
	var tooltip: String = TooltipText.item(_item("panzerglas"), 1)
	assert_string_contains(tooltip, "Einzigartig")
	assert_string_contains(tooltip, GOLD.to_html(false))


func test_offer_card_uses_gold_and_unique_label() -> void:
	var card: OfferCard = OfferCard.new()
	add_child_autofree(card)
	var item: ItemData = _item("kondensator")
	card.configure(item.icon, tr(item.name_key), item.tier, item.get_description())
	var style: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.border_color, GOLD)
	assert_gt(style.border_width_left, OfferCard.BORDER_WIDTH, "dickere Kontur")
	assert_eq(card._tier_label.text, "Einzigartig")


func test_lexicon_entry_and_filter_say_unique() -> void:
	var entry: LexiconEntry = Lexicon.item_entry(_item("sparlampe"))
	assert_eq(entry.subtitle, "Einzigartig")
	assert_eq(entry.tier, ItemData.UNIQUE_TIER)
	var names: PackedStringArray = []
	for section: LexiconSection in entry.sections:
		names.append(section.title)
	assert_has(names, tr("LEX_UNIQUE"))
	var items: Array[LexiconEntry] = Lexicon.entries(Lexicon.Tab.ITEMS)
	assert_eq(items.back().tier, ItemData.UNIQUE_TIER, "nach Tier sortiert stehen Einzigartige hinten")


# --- Tier 5 nie in Tier-Würfen (Kartons, Level-ups, normale Angebote) ---

func test_rarity_roll_never_reaches_tier_five() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for i in DRAWS:
		assert_lte(Rarity.roll_tier(20 + i % 30, 500.0, RARITY, rng.randf()), Rarity.MAX_TIER)
	assert_lte(Rarity.guaranteed_tier(50, RARITY), Rarity.MAX_TIER)


func test_loot_never_picks_unique_for_crates() -> void:
	var items: Array[ItemData] = []
	for res: Resource in DataRegistry.get_all("items"):
		items.append(res)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8
	var empty: Dictionary[StringName, int] = {}
	for i in DRAWS:
		var item: ItemData = Loot.pick_item(items, Rarity.MIN_TIER + i % Rarity.MAX_TIER, empty, [], 1.0, rng)
		assert_false(item.is_unique(), "Karton/Shop-Tier-Wurf liefert kein Einzigartiges")
	# Selbst wenn alle Tier-IV-Items am Limit sind, wird nicht auf Tier 5 ausgewichen.
	var only_unique: Array[ItemData] = _uniques()
	assert_null(Loot.pick_item(only_unique, Rarity.MAX_TIER, empty, [], 1.0, rng))


func test_level_up_upgrades_stay_within_tier_four() -> void:
	var upgrade: UpgradeData = DataRegistry.get_all("upgrades")[0]
	assert_eq(upgrade.value_for_tier(ItemData.UNIQUE_TIER), upgrade.value_for_tier(Rarity.MAX_TIER),
		"ein Tier über IV würde gekappt, kommt aber nie vor (roll_tier/guaranteed_tier)")


func test_weapons_never_combine_beyond_tier_four() -> void:
	var player: Player = _player()
	var weapon: WeaponData = load("res://data/weapons/funkenpistole.tres")
	player.weapon_slots.add_weapon(weapon, WeaponData.MAX_TIER)
	assert_null(player.weapon_slots.find_combine_partner(weapon, WeaponData.MAX_TIER))


# --- Shop ---

func test_no_unique_before_min_wave() -> void:
	var shop: Shop = Shop.create_from_registry()
	var ctx: ShopContext = _ctx(CONFIG.unique_min_wave - 1)
	ctx.luck = 500.0
	for i in SHORT_DRAWS:
		shop.reroll(ctx)
		assert_eq(_count_uniques(shop.offers), 0)


func test_uniques_appear_from_min_wave_at_most_one_per_offer() -> void:
	var shop: Shop = Shop.create_from_registry()
	var ctx: ShopContext = _ctx(CONFIG.unique_min_wave)
	var seen: int = 0
	for i in DRAWS:
		shop.reroll(ctx)
		var count: int = _count_uniques(shop.offers)
		assert_lte(count, 1)
		seen += count
	var expected: float = DRAWS * (1.0 - pow(1.0 - Shop.unique_chance(0.0), CONFIG.offer_count))
	assert_almost_eq(float(seen), expected, expected * 0.25, "Häufigkeit passt zur Config")


func test_locked_unique_blocks_a_second_one() -> void:
	var shop: Shop = Shop.create_from_registry()
	var ctx: ShopContext = _ctx(10)
	shop.open_shop(ctx)
	shop.place_offer(0, _item("panzerglas"), null, 0, ctx)
	for i in SHORT_DRAWS:
		shop.reroll(ctx)
		assert_eq(_count_uniques(shop.offers), 1, "gesperrtes Einzigartiges bleibt das einzige")


func test_owned_unique_never_offered_again() -> void:
	var shop: Shop = Shop.create_from_registry()
	var ctx: ShopContext = _ctx(12)
	for item: ItemData in _uniques():
		if item.id != &"kondensator":
			ctx.owned_items[item.id] = 1
	var offered: int = 0
	for i in DRAWS:
		shop.reroll(ctx)
		for offer: ShopOffer in shop.offers:
			if offer.item != null and offer.item.is_unique():
				assert_eq(offer.item.id, &"kondensator")
				offered += 1
	assert_gt(offered, 0)
	ctx.owned_items[&"kondensator"] = 1
	for i in SHORT_DRAWS:
		shop.reroll(ctx)
		assert_eq(_count_uniques(shop.offers), 0, "alle besessen: keine Einzigartigen mehr")


func test_unique_chance_luck_and_cap() -> void:
	assert_almost_eq(Shop.unique_chance(0.0), CONFIG.unique_chance, 0.0001)
	assert_gt(Shop.unique_chance(50.0), Shop.unique_chance(0.0), "Glück erhöht leicht")
	assert_lt(Shop.unique_chance(-50.0), Shop.unique_chance(0.0))
	assert_almost_eq(Shop.unique_chance(10000.0), CONFIG.unique_max_chance, 0.0001)
	assert_eq(Shop.unique_chance(-1000.0), 0.0)


func test_unique_price_uses_normal_inflation() -> void:
	var shop: Shop = Shop.create_from_registry()
	var ctx: ShopContext = _ctx(9)
	ctx.item_price_pct = 20.0
	var counts: Dictionary[StringName, int] = {}
	var offer: ShopOffer = shop.generate_unique_offer(ctx, counts)
	assert_eq(offer.tier, ItemData.UNIQUE_TIER)
	assert_eq(offer.price, Economy.inflated_price(offer.item.price, 9, 20.0))


# --- Stat pro Stat (live) ---

func test_panzerglas_updates_live_with_armor() -> void:
	var player: Player = _player()
	var before: float = player.stats.get_stat(Stats.DAMAGE_PCT)
	_give(player, "panzerglas")
	var armor: StatModifier = StatModifier.create(Stats.ARMOR, 12.0)
	player.add_run_modifier(armor)
	var armor_now: float = player.stats.get_stat(Stats.ARMOR)
	assert_eq(player.stats.get_stat(Stats.DAMAGE_PCT), before + floorf(armor_now))
	player.stats.remove_modifier(armor)
	assert_eq(player.stats.get_stat(Stats.DAMAGE_PCT), before + floorf(maxf(0.0, player.stats.get_stat(Stats.ARMOR))))


func test_conversion_rounding_is_exact() -> void:
	var stats: StatSystem = StatSystem.new()
	stats.add_conversion(Stats.SPEED, Stats.MELEE_DMG, 3.0, 1.0)
	stats.add_modifier(StatModifier.create(Stats.SPEED, 9.0))
	assert_eq(stats.get_stat(Stats.MELEE_DMG), 3.0, "9 / 3 = 3, nicht 2")
	stats.add_modifier(StatModifier.create(Stats.SPEED, -10.0))
	assert_eq(stats.get_stat(Stats.MELEE_DMG), 0.0, "negativer Ausgangswert zählt als 0")


func test_sparlampe_counts_sparks_with_cap() -> void:
	var player: Player = _player()
	var before: float = player.stats.get_stat(Stats.DAMAGE_PCT)
	var price_before: float = player.stats.get_stat(Stats.ITEM_PRICE_PCT)
	_give(player, "sparlampe")
	assert_eq(player.stats.get_stat(Stats.ITEM_PRICE_PCT), price_before + 10.0)
	Events.sparks_changed.emit(130, 0)
	assert_eq(player.stats.get_stat(Stats.DAMAGE_PCT), before + 6.0)
	Events.sparks_changed.emit(5000, 0)
	assert_eq(player.stats.get_stat(Stats.DAMAGE_PCT), before + 30.0, "höchstens +30 %")


func test_leuchtturm_follows_level() -> void:
	var player: Player = _player()
	var before: float = player.stats.get_stat(Stats.RANGE)
	_give(player, "leuchtturm")
	Events.xp_changed.emit(0.0, 10.0, 7)
	assert_eq(player.stats.get_stat(Stats.RANGE), before + 21.0)


func test_tooltip_lists_conversion_source() -> void:
	var player: Player = _player()
	_give(player, "panzerglas")
	player.add_run_modifier(StatModifier.create(Stats.ARMOR, 12.0))
	var text: String = TooltipText.stat(Stats.DAMAGE_PCT, INF, player.stats)
	assert_string_contains(text, tr("ITEM_PANZERGLAS"))
	assert_string_contains(text, "durch")


func test_hochspannungsspeicher_damage_per_max_hp_and_regen_malus() -> void:
	var player: Player = _player()
	var damage: float = player.stats.get_stat(Stats.DAMAGE_PCT)
	var regen: float = player.stats.get_stat(Stats.HP_REGEN)
	_give(player, "hochspannungsspeicher")
	assert_eq(player.stats.get_stat(Stats.DAMAGE_PCT), damage + floorf(player.stats.get_stat(Stats.MAX_HP) / 4.0))
	assert_eq(player.stats.get_stat(Stats.HP_REGEN), regen - 2.0)


# --- Bonus unter X % HP ---

func test_thermosicherung_only_below_threshold() -> void:
	var player: Player = _player()
	var speed: float = player.stats.get_stat(Stats.ATTACK_SPEED)
	_give(player, "thermosicherung")
	assert_eq(player.stats.get_stat(Stats.ATTACK_SPEED), speed)
	player.current_hp = player.get_max_hp() * 0.25
	player.update_low_hp()
	assert_eq(player.stats.get_stat(Stats.ATTACK_SPEED), speed + 40.0)
	player.heal(player.get_max_hp())
	assert_eq(player.stats.get_stat(Stats.ATTACK_SPEED), speed, "Heilung schaltet ab")


# --- Tödlichen Treffer überleben ---

func test_reservebatterie_once_per_wave() -> void:
	var player: Player = _player()
	_give(player, "reservebatterie")
	watch_signals(player)
	var entry: TriggerEntry = player.triggers[0]
	var ctx: EffectContext = EffectContext.create(player)
	entry.effect.on_wave_started(ctx, entry)
	assert_eq(entry.effect.hud_charge(entry), 1.0)
	player.take_hit(9999.0)
	assert_false(player.is_dead)
	assert_eq(player.current_hp, 1.0)
	assert_signal_emitted(player, "lethal_hit_survived")
	assert_eq(entry.effect.hud_charge(entry), 0.0, "HUD zeigt verbraucht")
	player.set("_invulnerable_left", 0.0)
	player.take_hit(9999.0)
	assert_true(player.is_dead, "zweiter tödlicher Treffer in derselben Welle")


func test_reservebatterie_refills_on_wave_start() -> void:
	var player: Player = _player()
	_give(player, "reservebatterie")
	var entry: TriggerEntry = player.triggers[0]
	var ctx: EffectContext = EffectContext.create(player)
	player.take_hit(9999.0)
	assert_eq(entry.effect.hud_charge(entry), 0.0)
	entry.effect.on_wave_started(ctx, entry)
	player.set("_invulnerable_left", 0.0)
	player.take_hit(9999.0)
	assert_false(player.is_dead)


# --- Nach N Kills ---

func test_kondensator_charges_every_weapon_after_kills() -> void:
	var player: Player = _player()
	player.weapon_slots.add_weapon(load("res://data/weapons/funkenpistole.tres"))
	player.weapon_slots.add_weapon(load("res://data/weapons/glasscherbe.tres"))
	_give(player, "kondensator")
	var entry: TriggerEntry = player.triggers[0]
	var effect: KillChargeEffect = entry.effect
	var ctx: EffectContext = EffectContext.create(player)
	ctx.origin = entry.origin
	for i in effect.kills_needed - 1:
		effect.on_enemy_killed(ctx, entry, Vector2.ZERO, null, null)
	assert_false(effect.is_charged(entry))
	assert_almost_eq(effect.hud_charge(entry), (effect.kills_needed - 1.0) / effect.kills_needed, 0.001)
	effect.on_enemy_killed(ctx, entry, Vector2.ZERO, null, null)
	assert_true(effect.is_charged(entry))
	# Ohne Krits, damit beide Würfe vergleichbar sind.
	player.rules[Player.Rule.NO_CRIT] = true
	var weapons: Array[Weapon] = player.weapon_slots.get_weapons()
	var normal: int = weapons[0]._roll_damage().amount
	effect.on_weapon_attack(ctx, entry, weapons[0], null)
	var info: DamageInfo = weapons[0]._roll_damage()
	assert_true(info.amount >= normal * 2 - 1, "doppelter Schaden")
	assert_eq(info.bonus_origin, DamageSource.item(&"kondensator"))
	assert_true(effect.is_charged(entry), "zweite Waffe noch geladen")
	effect.on_weapon_attack(ctx, entry, weapons[1], null)
	assert_false(effect.is_charged(entry))


func test_charged_hit_splits_damage_and_kill_in_run_stats() -> void:
	var player: Player = _player()
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = 30.0
	enemy.setup(data)
	enemy.activate(1, Vector2(500, 0), player, Rect2(), player.rng)
	enemy.set_physics_process(false)
	var weapon_origin: StringName = DamageSource.weapon(&"funkenpistole")
	var item_origin: StringName = DamageSource.item(&"kondensator")
	# Ohne Zusatz (Hälfte) überlebt der Gegner, mit Zusatz stirbt er.
	var hp_before: float = enemy.hp
	var amount: int = ceili(hp_before * 1.5)
	var info: DamageInfo = DamageInfo.create(amount, false, 0.0, null, weapon_origin)
	info.bonus_origin = item_origin
	info.bonus_share = 0.5
	enemy.take_damage(info)
	var dealt: int = GameState.run_stats.damage_of(weapon_origin) + GameState.run_stats.damage_of(item_origin)
	assert_eq(dealt, ceili(hp_before), "kein Overkill, Summe bleibt gleich")
	assert_gt(GameState.run_stats.damage_of(item_origin), 0)
	assert_eq(GameState.run_stats.kills_of(item_origin), 1, "erst der Zusatzschaden tötet")
	assert_eq(GameState.run_stats.kills_of(weapon_origin), 0)


func test_long_unique_names_fit_lexicon_cards() -> void:
	var width: float = EntryCard.CARD_SIZE.x - 2.0 * EntryCard.PADDING - UiStyle.TEXT_OUTLINE
	for item: ItemData in _uniques():
		for word: String in tr(item.name_key).split(" ", false):
			assert_lte(UiStyle.FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, EntryCard.MIN_NAME_SIZE).x, width,
				"%s bricht nicht mitten im Wort um" % word)
