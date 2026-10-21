class_name ShopScreen
extends FlowScreen
## Shop zwischen den Wellen (GDD 7): 4 Angebote, Kaufen, Sperren, Reroll, Waffeninventar mit Kombinieren
## und Recyceln, Item-Übersicht, Stat-Panel mit Vorher/Nachher-Vorschau und Sonderwellen-Vorschau.

const CONFIG: ShopConfig = preload("res://data/config/shop_config.tres")
const WAVE_CATEGORY: String = "waves"
const HEADER_SIZE: int = 40
const SECTION_SIZE: int = 26
const SMALL_SIZE: int = 18
const WEAPON_ICON: Vector2 = Vector2(48, 48)
const ITEM_ICON: Vector2 = Vector2(48, 48)
const MINI_BORDER: int = 3
const SECTION_GAP: int = 14

var _ctx: ShopContext
var _stat_panel: StatPanel
## Fokus-Ziele nach Namen, damit der Fokus nach einem Neuaufbau (Kauf, Reroll) erhalten bleibt.
var _focus_targets: Dictionary[String, Control] = {}


func open() -> void:
	_ctx = ShopContext.from_run(player)
	GameState.shop.open_shop(_ctx)
	_build("buy_0")
	show()


func _build(focus_hint: String) -> void:
	_clear()
	_focus_targets.clear()
	var shop: Shop = GameState.shop
	var root: HBoxContainer = _add_row()
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", SECTION_GAP)
	root.add_child(left)
	_stat_panel = StatPanel.new()
	root.add_child(_stat_panel)
	_stat_panel.setup(player.stats)

	# Kopfzeile
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", GAP)
	left.add_child(header)
	var title: Label = UiStyle.make_label(HEADER_SIZE)
	title.text = tr("SHOP_TITLE_WAVE") % _ctx.wave
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var sparks: Label = UiStyle.make_label(HEADER_SIZE, UiStyle.SPARK_COLOR)
	sparks.text = tr("SPARKS_AVAILABLE") % GameState.sparks
	header.add_child(sparks)
	var price: int = shop.reroll_price(_ctx)
	var reroll: Button = UiStyle.make_button(tr("REROLL") % price if price > 0 else tr("REROLL_FREE"), OfferCard.BUTTON_SIZE)
	reroll.disabled = price > GameState.sparks
	reroll.pressed.connect(_on_reroll)
	header.add_child(reroll)
	_focus_targets["reroll"] = reroll
	var next: Button = UiStyle.make_button(tr("NEXT_WAVE"), OfferCard.BUTTON_SIZE)
	next.pressed.connect(_on_next_wave)
	header.add_child(next)
	_focus_targets["next"] = next

	# Angebote
	var offers_row: HBoxContainer = HBoxContainer.new()
	offers_row.add_theme_constant_override("separation", GAP)
	left.add_child(offers_row)
	for i in shop.offers.size():
		offers_row.add_child(_offer_card(i, shop.offers[i]))

	_build_weapons(left)
	_build_items(left)
	_build_preview(left)
	_focus_later(_focus_targets.get(focus_hint, _focus_targets.get("next")))


func _offer_card(index: int, offer: ShopOffer) -> OfferCard:
	var card: OfferCard = OfferCard.new()
	if offer.is_weapon():
		card.configure(offer.weapon.texture, tr(offer.weapon.name_key), offer.tier,
			TextFormat.describe_weapon(offer.weapon, offer.tier))
	else:
		card.configure(offer.item.icon, tr(offer.item.name_key), offer.tier,
			offer.item.get_description())
		card.preview_modifiers = offer.get_modifiers()
	card.focused.connect(func(c: OfferCard) -> void: _stat_panel.refresh(c.preview_modifiers))
	if offer.sold:
		card.set_status(tr("SOLD"), UiStyle.TIER_COLORS[0])
		return card
	var affordable: bool = offer.price <= GameState.sparks
	card.set_price(offer.price, affordable)
	var fits: bool = not offer.is_weapon() or player.weapon_slots.can_accept(offer.weapon, offer.tier)
	_focus_targets["buy_%d" % index] = card.add_action(tr("BUY"), _on_buy.bind(index), not affordable or not fits)
	_focus_targets["lock_%d" % index] = card.add_side_action(tr("UNLOCK") if offer.locked else tr("LOCK"), _on_lock.bind(index))
	return card


func _build_weapons(parent: VBoxContainer) -> void:
	var slots: WeaponSlots = player.weapon_slots
	var weapons: Array[Weapon] = slots.get_weapons()
	var label: Label = UiStyle.make_label(SECTION_SIZE)
	label.text = tr("SHOP_WEAPONS") % [weapons.size(), slots.max_slots]
	parent.add_child(label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	parent.add_child(row)
	for i in weapons.size():
		var weapon: Weapon = weapons[i]
		var panel: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = UiStyle.panel_style()
		style.border_color = UiStyle.tier_color(weapon.tier)
		style.set_border_width_all(MINI_BORDER)
		panel.add_theme_stylebox_override("panel", style)
		row.add_child(panel)
		var box: VBoxContainer = VBoxContainer.new()
		panel.add_child(box)
		var icon: TextureRect = TextureRect.new()
		icon.texture = weapon.data.texture
		icon.custom_minimum_size = WEAPON_ICON
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.tooltip_text = tr(weapon.data.name_key)
		box.add_child(icon)
		var tier_label: Label = UiStyle.make_label(SMALL_SIZE, UiStyle.tier_color(weapon.tier))
		tier_label.text = TextFormat.tier_name(weapon.tier)
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tier_label)
		if slots.find_combine_partner(weapon.data, weapon.tier, weapon) != null:
			var combine: Button = UiStyle.make_button(tr("COMBINE"), SMALL_SIZE)
			combine.pressed.connect(_on_combine.bind(weapon))
			box.add_child(combine)
			_focus_targets["combine_%d" % i] = combine
		var recycle: Button = UiStyle.make_button(tr("RECYCLE") % _weapon_recycle_value(weapon), SMALL_SIZE)
		recycle.pressed.connect(_on_recycle_weapon.bind(weapon))
		box.add_child(recycle)
		_focus_targets["recycle_%d" % i] = recycle


func _build_items(parent: VBoxContainer) -> void:
	var label: Label = UiStyle.make_label(SECTION_SIZE)
	label.text = tr("SHOP_ITEMS")
	parent.add_child(label)
	var flow: HFlowContainer = HFlowContainer.new()
	parent.add_child(flow)
	var counts: Dictionary[StringName, int] = GameState.item_counts()
	var shown: Dictionary[StringName, bool] = {}
	for item: ItemData in GameState.items:
		if shown.has(item.id):
			continue
		shown[item.id] = true
		var icon: TextureRect = TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = ITEM_ICON
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.tooltip_text = tr(item.name_key)
		flow.add_child(icon)
		if counts[item.id] > 1:
			var count: Label = UiStyle.make_label(SMALL_SIZE)
			count.text = "x%d" % counts[item.id]
			count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			icon.add_child(count)


func _build_preview(parent: VBoxContainer) -> void:
	var label: Label = UiStyle.make_label(SMALL_SIZE, UiStyle.HP_COLOR)
	var specials: PackedStringArray = []
	var waves: Array[Resource] = DataRegistry.get_all(WAVE_CATEGORY)
	waves.sort_custom(func(a: Resource, b: Resource) -> bool: return (a as WaveData).wave_number < (b as WaveData).wave_number)
	for res: Resource in waves:
		var wave: WaveData = res as WaveData
		if wave.wave_number <= _ctx.wave:
			continue
		if wave.is_boss:
			specials.append(tr("PREVIEW_BOSS") % wave.wave_number)
		elif GameState.special_waves.get(wave.wave_number, "") == WaveManager.SPECIAL_ELITE:
			specials.append(tr("PREVIEW_ELITE") % wave.wave_number)
		elif GameState.special_waves.get(wave.wave_number, "") == WaveManager.SPECIAL_HORDE:
			specials.append(tr("PREVIEW_HORDE") % wave.wave_number)
	label.text = tr("PREVIEW_TITLE") % (", ".join(specials) if not specials.is_empty() else tr("PREVIEW_NONE"))
	parent.add_child(label)


func _weapon_recycle_value(weapon: Weapon) -> int:
	var price: int = Economy.inflated_price(weapon.get_tier_stats().price, _ctx.wave, _ctx.item_price_pct)
	return Economy.recycle_value(price, CONFIG.recycle_share, player.stats.get_stat(Stats.RECYCLE_PCT))


func _refresh_context() -> void:
	var rng: RandomNumberGenerator = _ctx.rng
	_ctx = ShopContext.from_run(player)
	_ctx.rng = rng


func _on_buy(index: int) -> void:
	var offer: ShopOffer = GameState.shop.offers[index]
	if offer.is_weapon() and not player.weapon_slots.can_accept(offer.weapon, offer.tier):
		return
	if not GameState.spend(offer.price):
		return
	if offer.is_weapon():
		player.weapon_slots.add_or_combine(offer.weapon, offer.tier)
	else:
		GameState.add_item(offer.item)
		player.apply_item(offer.item)
	AudioManager.play(&"buy")
	GameState.shop.mark_sold(index)
	_refresh_context()
	_build.call_deferred("lock_%d" % index)


func _on_lock(index: int) -> void:
	GameState.shop.toggle_lock(index)
	_build.call_deferred("lock_%d" % index)


func _on_reroll() -> void:
	if not GameState.spend(GameState.shop.reroll_price(_ctx)):
		return
	AudioManager.play(&"reroll")
	GameState.shop.reroll(_ctx)
	_build.call_deferred("reroll")


func _on_combine(weapon: Weapon) -> void:
	AudioManager.play(&"buy")
	player.weapon_slots.combine(weapon)
	_refresh_context()
	_build.call_deferred("next")


func _on_recycle_weapon(weapon: Weapon) -> void:
	AudioManager.play(&"ui_click")
	GameState.add_sparks(_weapon_recycle_value(weapon))
	player.weapon_slots.remove_weapon(weapon)
	_refresh_context()
	_build.call_deferred("next")


func _on_next_wave() -> void:
	AudioManager.play(&"ui_click")
	GameState.set_phase.call_deferred(GameState.Phase.WAVE)
