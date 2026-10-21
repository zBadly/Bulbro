extends GutTest
## Layout-Stabilität (14a): Angebotskarten mit fester Höhe, Charakterauswahl springt beim Auswählen nicht.

const RUN_SETUP_SCENE: PackedScene = preload("res://scenes/ui/run_setup.tscn")
const SHORT_TEXT: String = "+1 Glück"
const LONG_LINE: String = "Eine sehr lange Zeile mit Beschreibungstext für die Karte"
const LONG_LINES: int = 20


func _card_row(texts: Array[String]) -> Array[OfferCard]:
	var row: HBoxContainer = HBoxContainer.new()
	add_child_autofree(row)
	var cards: Array[OfferCard] = []
	for text: String in texts:
		var card: OfferCard = OfferCard.new()
		card.configure(null, "Name", 1, text)
		card.set_price(10, true)
		card.add_side_action("Sperren", func() -> void: pass)
		card.add_action("Kaufen", func() -> void: pass)
		row.add_child(card)
		cards.append(card)
	return cards


func test_cards_have_same_height_and_aligned_prices() -> void:
	var long_text: String = "\n".join(PackedStringArray([LONG_LINE, LONG_LINE, LONG_LINE, LONG_LINE, LONG_LINE, LONG_LINE]))
	var cards: Array[OfferCard] = _card_row([SHORT_TEXT, long_text, SHORT_TEXT + "\n" + SHORT_TEXT, ""])
	await wait_physics_frames(3)
	for card: OfferCard in cards:
		assert_eq(card.size.y, OfferCard.CARD_SIZE.y, "feste Kartenhöhe")
	var price_y: float = (cards[0].get("_price") as Control).global_position.y
	for card: OfferCard in cards:
		assert_almost_eq((card.get("_price") as Control).global_position.y, price_y, 0.5, "Preise auf einer Linie")


func test_overlong_description_shrinks_font_instead_of_card() -> void:
	var lines: PackedStringArray = []
	for i in LONG_LINES:
		lines.append(LONG_LINE)
	var cards: Array[OfferCard] = _card_row(["\n".join(lines), SHORT_TEXT])
	await wait_physics_frames(3)
	assert_eq(cards[0].size.y, OfferCard.CARD_SIZE.y)
	assert_lt(cards[0].get_description_font_size(), OfferCard.DESC_SIZE, "Schrift verkleinert")
	assert_eq(cards[1].get_description_font_size(), OfferCard.DESC_SIZE, "kurzer Text behält die Größe")


func test_character_grid_does_not_move_on_selection() -> void:
	var setup: Control = RUN_SETUP_SCENE.instantiate()
	add_child_autofree(setup)
	await wait_physics_frames(3)
	var grid: GridContainer = _find_grid(setup)
	var buttons: Array[Node] = grid.get_children()
	var first: Control = buttons[0]
	var detail_panel: Control = (setup.get("_detail") as Control).get_parent().get_parent()
	var positions: Array[Vector2] = []
	var panel_sizes: Array[Vector2] = []
	for index: int in [0, buttons.size() - 1, 1, buttons.size() - 2]:
		(buttons[index] as Control).grab_focus()
		await wait_physics_frames(3)
		positions.append(first.global_position)
		panel_sizes.append(detail_panel.size)
	for i in positions.size():
		assert_eq(positions[i], positions[0], "Raster bleibt stehen")
		assert_eq(panel_sizes[i], panel_sizes[0], "Infopanel hat feste Größe")


func _find_grid(node: Node) -> GridContainer:
	if node is GridContainer:
		return node
	for child: Node in node.get_children():
		var found: GridContainer = _find_grid(child)
		if found != null:
			return found
	return null
