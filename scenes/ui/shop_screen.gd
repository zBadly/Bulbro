class_name ShopScreen
extends FlowScreen
## Shop zwischen den Wellen (GDD 7): 4 Angebote, Kaufen, Sperren, Reroll, Waffen- und Begleiterinventar mit
## Kombinieren und Recyceln, Item-Übersicht, aktive Set-Boni, Stat-Panel mit Vorher/Nachher-Vorschau und
## Sonderwellen-Vorschau. Besessene Waffen, Begleiter, Items und Set-Boni zeigen Tooltips (Maus und Gamepad-Fokus).
## Sind alle Begleiter-Plätze belegt, fragt der Shop beim Kauf, welcher Begleiter ersetzt wird.

const CONFIG: ShopConfig = preload("res://data/config/shop_config.tres")
const PETS: PetConfig = preload("res://data/config/pet_config.tres")
const WAVE_CATEGORY: String = "waves"
const HEADER_SIZE: int = 40
const SECTION_SIZE: int = 26
const SMALL_SIZE: int = 18
const WEAPON_ICON: Vector2 = Vector2(48, 48)
const ITEM_ICON: Vector2 = Vector2(48, 48)
const MINI_BORDER: int = 3
const SECTION_GAP: int = 14
const SET_CHIP_GAP: int = 8
const INVENTORY_GAP: int = 48
const DIALOG_PADDING: int = 28

var _ctx: ShopContext
var _stat_panel: StatPanel
## Fokus-Ziele nach Namen, damit der Fokus nach einem Neuaufbau (Kauf, Reroll) erhalten bleibt.
var _focus_targets: Dictionary[String, Control] = {}
## Rückfrage "Welchen Begleiter ersetzen?" (null, solange keine offen ist).
var _replace_dialog: Control


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
	var price: int = _reroll_price()
	var reroll: Button = UiStyle.make_button(tr("REROLL") % price if price > 0 else tr("REROLL_FREE"), OfferCard.BUTTON_SIZE)
	reroll.disabled = price > GameState.sparks
	reroll.pressed.connect(_on_reroll)
	header.add_child(reroll)
	_focus_targets["reroll"] = reroll
	var next: Button = UiStyle.make_button(tr("NEXT_WAVE"), OfferCard.BUTTON_SIZE)
	next.pressed.connect(_on_next_wave)
	header.add_child(next)
	_focus_targets["next"] = next
	if _boss_wave_numbers().has(_ctx.wave + 1):
		var warning: Label = UiStyle.make_label(SECTION_SIZE, UiStyle.HP_COLOR)
		warning.text = tr("SHOP_NEXT_BOSSES") if GameState.endless else tr("SHOP_NEXT_BOSS")
		left.add_child(warning)

	# Angebote
	var offers_row: HBoxContainer = HBoxContainer.new()
	offers_row.add_theme_constant_override("separation", GAP)
	left.add_child(offers_row)
	for i in shop.offers.size():
		offers_row.add_child(_offer_card(i, shop.offers[i]))

	var inventory: HBoxContainer = HBoxContainer.new()
	inventory.add_theme_constant_override("separation", INVENTORY_GAP)
	left.add_child(inventory)
	var weapons_box: VBoxContainer = VBoxContainer.new()
	inventory.add_child(weapons_box)
	_build_weapons(weapons_box)
	var pets_box: VBoxContainer = VBoxContainer.new()
	inventory.add_child(pets_box)
	_build_pets(pets_box)
	_build_items(left)
	_build_preview(left)
	_focus_later(_focus_targets.get(focus_hint, _focus_targets.get("next")))


func _offer_card(index: int, offer: ShopOffer) -> OfferCard:
	var card: OfferCard = OfferCard.new()
	if offer.is_weapon():
		card.configure(offer.weapon.texture, tr(offer.weapon.name_key), offer.tier,
			TextFormat.describe_weapon(offer.weapon, offer.tier))
	elif offer.is_pet():
		card.configure(offer.pet.texture, tr(offer.pet.name_key), offer.tier, offer.pet.get_description(offer.tier))
	else:
		card.configure(offer.item.icon, tr(offer.item.name_key), offer.tier,
			offer.item.get_description())
		card.preview_modifiers = offer.get_modifiers()
	card.focused.connect(func(c: OfferCard) -> void: _stat_panel.refresh(c.preview_modifiers))
	if offer.sold:
		card.set_status(tr("SOLD"), UiStyle.TIER_COLORS[0])
		return card
	var affordable: bool = _offer_price(offer) <= GameState.sparks
	card.set_price(_offer_price(offer), affordable)
	var fits: bool = not offer.is_weapon() or player.weapon_slots.can_accept(offer.weapon, offer.tier)
	_focus_targets["buy_%d" % index] = card.add_action(tr("BUY"), _on_buy.bind(index), not affordable or not fits)
	_focus_targets["lock_%d" % index] = card.add_side_action(tr("UNLOCK") if offer.locked else tr("LOCK"), _on_lock.bind(index))
	return card


func _build_weapons(parent: VBoxContainer) -> void:
	var slots: WeaponSlots = player.weapon_slots
	var weapons: Array[Weapon] = slots.get_weapons()
	# Kopfzeile: "Waffen (6/6)" und daneben die aktiven Set-Boni (spart eine Zeile)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", GAP)
	parent.add_child(header)
	var label: Label = UiStyle.make_label(SECTION_SIZE)
	label.text = tr("SHOP_WEAPONS") % [weapons.size(), slots.max_slots]
	header.add_child(label)
	_build_set_bonuses(header)
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
		var tooltip: Callable = TooltipText.weapon.bind(weapon)
		GameTooltip.attach(icon, tooltip, true, false)
		box.add_child(icon)
		var tier_label: Label = UiStyle.make_label(SMALL_SIZE, UiStyle.tier_color(weapon.tier))
		tier_label.text = TextFormat.tier_name(weapon.tier)
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tier_label)
		if slots.find_combine_partner(weapon.data, weapon.tier, weapon) != null:
			var combine: Button = UiStyle.make_button(tr("COMBINE"), SMALL_SIZE)
			combine.pressed.connect(_on_combine.bind(weapon))
			GameTooltip.attach(combine, tooltip, false, true)
			box.add_child(combine)
			_focus_targets["combine_%d" % i] = combine
		var recycle: Button = UiStyle.make_button(tr("RECYCLE") % _weapon_recycle_value(weapon), SMALL_SIZE)
		recycle.pressed.connect(_on_recycle_weapon.bind(weapon))
		GameTooltip.attach(recycle, tooltip, false, true)
		box.add_child(recycle)
		_focus_targets["recycle_%d" % i] = recycle


## Begleiter (x/2) mit Tier, Kombinieren und Recyceln, wie die Waffen.
func _build_pets(parent: VBoxContainer) -> void:
	var pets: Array[Pet] = player.pet_slots.get_pets()
	var label: Label = UiStyle.make_label(SECTION_SIZE)
	label.text = tr("SHOP_PETS") % [pets.size(), PETS.max_pets]
	parent.add_child(label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	parent.add_child(row)
	if pets.is_empty():
		var none: Label = UiStyle.make_label(SMALL_SIZE, UiStyle.TIER_COLORS[0])
		none.text = tr("SHOP_PETS_NONE")
		row.add_child(none)
		return
	for i in pets.size():
		var pet: Pet = pets[i]
		var panel: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = UiStyle.panel_style()
		style.border_color = UiStyle.tier_color(pet.tier)
		style.set_border_width_all(MINI_BORDER)
		panel.add_theme_stylebox_override("panel", style)
		row.add_child(panel)
		var box: VBoxContainer = VBoxContainer.new()
		panel.add_child(box)
		var icon: TextureRect = TextureRect.new()
		icon.texture = pet.data.texture
		icon.custom_minimum_size = WEAPON_ICON
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var tooltip: Callable = TooltipText.pet.bind(pet)
		GameTooltip.attach(icon, tooltip, true, false)
		box.add_child(icon)
		var tier_label: Label = UiStyle.make_label(SMALL_SIZE, UiStyle.tier_color(pet.tier))
		tier_label.text = TextFormat.tier_name(pet.tier)
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tier_label)
		if player.pet_slots.find_combine_partner(pet.data, pet.tier, pet) != null:
			var combine: Button = UiStyle.make_button(tr("COMBINE"), SMALL_SIZE)
			combine.pressed.connect(_on_combine_pet.bind(pet))
			GameTooltip.attach(combine, tooltip, false, true)
			box.add_child(combine)
			_focus_targets["combine_pet_%d" % i] = combine
		var recycle: Button = UiStyle.make_button(tr("RECYCLE") % pet_recycle_value(pet), SMALL_SIZE)
		recycle.pressed.connect(_on_recycle_pet.bind(pet))
		GameTooltip.attach(recycle, tooltip, false, true)
		box.add_child(recycle)
		_focus_targets["recycle_pet_%d" % i] = recycle


func _build_items(parent: VBoxContainer) -> void:
	var label: Label = UiStyle.make_label(SECTION_SIZE)
	label.text = tr("SHOP_ITEMS")
	parent.add_child(label)
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", MINI_BORDER * 2)
	flow.add_theme_constant_override("v_separation", MINI_BORDER * 2)
	parent.add_child(flow)
	for entry: Dictionary in BuildOverview.item_stacks():
		var data: ItemData = entry["item"]
		var count: int = entry["count"]
		var icon: BuildIcon = BuildIcon.new(data.icon, data.tier, count, TooltipText.item.bind(data, count), ITEM_ICON)
		flow.add_child(icon)
		_focus_targets["item_%s" % data.id] = icon


## Leiste "Aktive Set-Boni": je Klasse mit mindestens 2 Waffen ein Chip "Klinge 3/6" mit Tooltip aller Stufen.
func _build_set_bonuses(parent: HBoxContainer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", SET_CHIP_GAP)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(row)
	var label: Label = UiStyle.make_label(SMALL_SIZE)
	label.text = tr("SHOP_SET_BONUSES")
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var counts: Dictionary[StringName, int] = TooltipText.class_counts(player.weapon_slots.get_weapons())
	var any: bool = false
	for weapon_class: StringName in WeaponClasses.ALL:
		var count: int = counts.get(weapon_class, 0)
		var set_bonus: SetBonusData = TooltipText.set_bonus_for(weapon_class)
		if count < SetBonusData.MIN_WEAPONS or set_bonus == null:
			continue
		any = true
		var chip: Button = UiStyle.make_button(tr("SHOP_SET_CHIP") % [tr(WeaponClasses.label_key(weapon_class)), count, TooltipText.max_level(set_bonus)], SMALL_SIZE)
		var factor: float = player.set_bonus_multiplier.get(weapon_class, 1.0)
		GameTooltip.attach(chip, TooltipText.set_bonus_text.bind(set_bonus, count, factor))
		row.add_child(chip)
		_focus_targets["set_%s" % weapon_class] = chip
	if not any:
		var none: Label = UiStyle.make_label(SMALL_SIZE, UiStyle.TIER_COLORS[0])
		none.text = tr("SHOP_SET_NONE")
		none.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(none)


func _build_preview(parent: VBoxContainer) -> void:
	var label: Label = UiStyle.make_label(SMALL_SIZE, UiStyle.HP_COLOR)
	var specials: PackedStringArray = []
	var bosses: Array[int] = _boss_wave_numbers()
	var numbers: Array[int] = bosses.duplicate()
	for number: int in GameState.special_waves:
		if number not in numbers:
			numbers.append(number)
	numbers.sort()
	for number: int in numbers:
		if number <= _ctx.wave:
			continue
		if number in bosses:
			specials.append(tr("PREVIEW_BOSS") % number)
		elif GameState.special_waves[number] == WaveManager.SPECIAL_ELITE:
			specials.append(tr("PREVIEW_ELITE") % number)
		elif GameState.special_waves[number] == WaveManager.SPECIAL_HORDE:
			specials.append(tr("PREVIEW_HORDE") % number)
	label.text = tr("PREVIEW_TITLE") % (", ".join(specials) if not specials.is_empty() else tr("PREVIEW_NONE"))
	parent.add_child(label)


## Bosswellen in Reichweite der Vorschau: die letzte reguläre Welle, im Endlos-Modus die nächste Bosswelle.
func _boss_wave_numbers() -> Array[int]:
	var result: Array[int] = []
	if GameState.endless:
		var cycle: int = EndlessRules.CONFIG.boss_cycle_waves
		for number: int in range(_ctx.wave + 1, _ctx.wave + cycle + 1):
			if EndlessRules.is_boss_level(number - GameState.endless_start_wave):
				result.append(number)
		return result
	for res: Resource in DataRegistry.get_all(WAVE_CATEGORY):
		if (res as WaveData).is_boss:
			result.append((res as WaveData).wave_number)
	return result


func _weapon_recycle_value(weapon: Weapon) -> int:
	var price: int = Economy.inflated_price(weapon.get_tier_stats().price, _ctx.wave, _ctx.item_price_pct)
	return Economy.recycle_value(price, CONFIG.recycle_share, player.stats.get_stat(Stats.RECYCLE_PCT))


## Rückgabe beim Recyceln oder Ersetzen eines Begleiters (wie bei Waffen: Anteil des aktuellen Preises).
func pet_recycle_value(pet: Pet) -> int:
	var price: int = Economy.inflated_price(pet.get_tier_stats().price, _ctx.wave, _ctx.item_price_pct)
	return Economy.recycle_value(price, PETS.recycle_share, player.stats.get_stat(Stats.RECYCLE_PCT))


func _refresh_context() -> void:
	var rng: RandomNumberGenerator = _ctx.rng
	_ctx = ShopContext.from_run(player)
	_ctx.rng = rng


func _on_buy(index: int) -> void:
	var offer: ShopOffer = GameState.shop.offers[index]
	if offer.is_weapon() and not player.weapon_slots.can_accept(offer.weapon, offer.tier):
		return
	if offer.is_pet() and not player.pet_slots.can_accept(offer.pet, offer.tier):
		if _offer_price(offer) <= GameState.sparks:
			_ask_replace(index)
		return
	if not GameState.spend(_offer_price(offer)):
		return
	if offer.is_weapon():
		player.weapon_slots.add_or_combine(offer.weapon, offer.tier)
	elif offer.is_pet():
		player.pet_slots.add_or_combine(offer.pet, offer.tier)
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
	if not GameState.spend(_reroll_price()):
		return
	AudioManager.play(&"reroll")
	GameState.run_stats.rerolls += 1
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


func _on_combine_pet(pet: Pet) -> void:
	AudioManager.play(&"buy")
	player.pet_slots.combine(pet)
	_build.call_deferred("next")


func _on_recycle_pet(pet: Pet) -> void:
	AudioManager.play(&"ui_click")
	GameState.add_sparks(pet_recycle_value(pet))
	player.pet_slots.remove_pet(pet)
	_build.call_deferred("next")


## Rückfrage bei vollen Begleiter-Plätzen: je Begleiter "X ersetzen (+N Funken)" und "Abbrechen".
func _ask_replace(index: int) -> void:
	close_replace_dialog()
	var offer: ShopOffer = GameState.shop.offers[index]
	_replace_dialog = Control.new()
	_replace_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_replace_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_replace_dialog)
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_replace_dialog.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_replace_dialog.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.panel_style()
	style.border_color = UiStyle.tier_color(offer.tier)
	style.set_border_width_all(MINI_BORDER)
	style.set_content_margin_all(DIALOG_PADDING)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	panel.add_child(box)
	var title: Label = UiStyle.make_label(SECTION_SIZE)
	title.text = tr("SHOP_PET_REPLACE_TITLE") % [PETS.max_pets, tr(offer.pet.name_key), TextFormat.tier_name(offer.tier)]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var first: Button = null
	for pet: Pet in player.pet_slots.get_pets():
		var button: Button = UiStyle.make_button(tr("SHOP_PET_REPLACE") % [tr(pet.data.name_key), TextFormat.tier_name(pet.tier),
			pet_recycle_value(pet)], OfferCard.BUTTON_SIZE)
		button.pressed.connect(_on_replace.bind(index, pet))
		GameTooltip.attach(button, TooltipText.pet.bind(pet), false, true)
		box.add_child(button)
		if first == null:
			first = button
	var cancel: Button = UiStyle.make_button(tr("SHOP_PET_KEEP"), OfferCard.BUTTON_SIZE)
	cancel.pressed.connect(_on_replace_cancel.bind(index))
	box.add_child(cancel)
	_focus_later(first)


func _on_replace(index: int, old: Pet) -> void:
	var offer: ShopOffer = GameState.shop.offers[index]
	close_replace_dialog()
	if not GameState.spend(_offer_price(offer)):
		return
	GameState.add_sparks(pet_recycle_value(old))
	player.pet_slots.replace(old, offer.pet, offer.tier)
	AudioManager.play(&"buy")
	GameState.shop.mark_sold(index)
	_refresh_context()
	_build.call_deferred("lock_%d" % index)


func _on_replace_cancel(index: int) -> void:
	close_replace_dialog()
	_build.call_deferred("buy_%d" % index)


func close_replace_dialog() -> void:
	if _replace_dialog != null:
		_replace_dialog.queue_free()
		_replace_dialog = null


func is_replace_dialog_open() -> bool:
	return _replace_dialog != null


func _unhandled_input(event: InputEvent) -> void:
	if _replace_dialog != null and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_replace_dialog()
		_build.call_deferred("next")


func close() -> void:
	close_replace_dialog()
	super.close()


func _on_next_wave() -> void:
	AudioManager.play(&"ui_click")
	GameState.set_phase.call_deferred(GameState.Phase.WAVE)


## Preis mit Admin-Schalter "Alles kostenlos".
func _offer_price(offer: ShopOffer) -> int:
	return 0 if GameState.admin.shop_free else offer.price


func _reroll_price() -> int:
	return 0 if GameState.admin.free_reroll else GameState.shop.reroll_price(_ctx)


## Admin: Angebote nach einer Änderung neu aufbauen (nur wenn der Shop offen ist).
func refresh() -> void:
	if visible:
		_build("next")
