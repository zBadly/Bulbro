class_name ShopScreen
extends FlowScreen
## Shop zwischen den Wellen (Platzhalter bis Phase 7).


func open() -> void:
	_clear()
	_add_title(tr("SHOP_TITLE"))
	_add_title(tr("SPARKS_AVAILABLE") % GameState.sparks, SUBTITLE_SIZE, UiStyle.SPARK_COLOR)
	var next: Button = UiStyle.make_button(tr("NEXT_WAVE"), OfferCard.BUTTON_SIZE)
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(_on_next_wave)
	_content.add_child(next)
	show()
	_focus_later(next)


func _on_next_wave() -> void:
	GameState.set_phase.call_deferred(GameState.Phase.WAVE)
