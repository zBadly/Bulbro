class_name CrateScreen
extends FlowScreen
## Öffnet Ersatzteil-Kartons nacheinander: Item nehmen oder für 25 % des Preises recyceln.

const RARITY: RarityConfig = preload("res://data/config/rarity_config.tres")
const SHOP: ShopConfig = preload("res://data/config/shop_config.tres")
const ITEM_CATEGORY: String = "items"

var _item: ItemData
var _recycle_value: int = 0


func open() -> void:
	_clear()
	_item = _roll_item()
	if _item == null:
		GameState.finish_crate.call_deferred()
		return
	var wave: int = GameState.current_wave
	var price: int = Economy.inflated_price(_item.price, wave, player.stats.get_stat(Stats.ITEM_PRICE_PCT))
	_recycle_value = Economy.recycle_value(price, SHOP.recycle_share, player.stats.get_stat(Stats.RECYCLE_PCT))

	_add_title(tr("CRATE_LEGENDARY_TITLE") if GameState.pending_legendary_crates > 0 else tr("CRATE_TITLE"))
	if GameState.pending_crates > 1:
		_add_title(tr("CRATE_REMAINING") % (GameState.pending_crates - 1), SUBTITLE_SIZE)
	var card: OfferCard = OfferCard.new()
	card.configure(_item.icon, tr(_item.name_key), _item.tier, _item.get_description())
	var take: Button = card.add_action(tr("TAKE"), _on_take)
	card.add_action(tr("RECYCLE") % _recycle_value, _on_recycle)
	_add_row().add_child(card)
	show()
	_focus_later(take)


func _roll_item() -> ItemData:
	var items: Array[ItemData] = []
	for res: Resource in DataRegistry.get_all(ITEM_CATEGORY):
		items.append(res as ItemData)
	var rng: RandomNumberGenerator = GameState.rng
	var tier: int = Rarity.roll_tier(GameState.current_wave, player.stats.get_stat(Stats.LUCK), RARITY, rng.randf())
	if GameState.pending_legendary_crates > 0:
		tier = Rarity.MAX_TIER
	return Loot.pick_item(items, tier, GameState.item_counts(), GameState.preferred_tags, SHOP.preferred_tag_weight, rng)


func _on_take() -> void:
	GameState.add_item(_item)
	player.apply_item(_item)
	GameState.finish_crate.call_deferred()


func _on_recycle() -> void:
	GameState.add_sparks(_recycle_value)
	GameState.finish_crate.call_deferred()
