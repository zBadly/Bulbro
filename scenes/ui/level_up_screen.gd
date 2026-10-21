class_name LevelUpScreen
extends FlowScreen
## Ein Bildschirm pro Level-up: 4 Upgrade-Karten, Reroll gegen Funken, garantierte Seltenheit auf Level 5/10/15/20/25+.

const RARITY: RarityConfig = preload("res://data/config/rarity_config.tres")
const SHOP: ShopConfig = preload("res://data/config/shop_config.tres")
const UPGRADE_CATEGORY: String = "upgrades"

var _level: int = 0
var _rerolls: int = 0


func open() -> void:
	_level = GameState.level_being_upgraded()
	_rerolls = 0
	_build()
	show()


func _build() -> void:
	_clear()
	_add_title(tr("LEVEL_UP_TITLE") % _level)
	_add_title(tr("SPARKS_AVAILABLE") % GameState.sparks, SUBTITLE_SIZE, UiStyle.SPARK_COLOR)
	var row: HBoxContainer = _add_row()
	var first: Button = null
	var rng: RandomNumberGenerator = GameState.rng
	var luck: float = player.stats.get_stat(Stats.LUCK)
	var min_tier: int = Rarity.guaranteed_tier(_level, RARITY)
	for upgrade: UpgradeData in Loot.pick_upgrades(_all_upgrades(), SHOP.upgrade_card_count, rng):
		var tier: int = maxi(min_tier, Rarity.roll_tier(_level, luck, RARITY, rng.randf()))
		var mod: StatModifier = upgrade.modifier_for_tier(tier)
		var card: OfferCard = OfferCard.new()
		card.configure(upgrade.icon, tr(Stats.label_key(upgrade.stat)), tier, TextFormat.modifier_line(mod))
		var button: Button = card.add_action(tr("CHOOSE"), _on_choose.bind(mod))
		if first == null:
			first = button
		row.add_child(card)

	var price: int = _reroll_price()
	var reroll: Button = UiStyle.make_button(tr("REROLL") % price, OfferCard.BUTTON_SIZE)
	reroll.disabled = price > GameState.sparks
	reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll.pressed.connect(_on_reroll)
	_content.add_child(reroll)
	_focus_later(first)


func _all_upgrades() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for res: Resource in DataRegistry.get_all(UPGRADE_CATEGORY):
		result.append(res as UpgradeData)
	return result


func _reroll_price() -> int:
	return Economy.reroll_price(GameState.current_wave, _rerolls, SHOP.reroll_increment_factor,
		player.stats.get_stat(Stats.REROLL_PRICE_PCT))


func _on_reroll() -> void:
	if not GameState.spend(_reroll_price()):
		return
	AudioManager.play(&"reroll")
	_rerolls += 1
	_build.call_deferred()


func _on_choose(mod: StatModifier) -> void:
	AudioManager.play(&"ui_click")
	player.add_run_modifier(mod)
	GameState.finish_level_up.call_deferred()
