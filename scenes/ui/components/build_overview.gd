class_name BuildOverview
extends VBoxContainer
## Waffen, Begleiter und Items des Runs als Icons mit Tooltips (Pause-Menü und Run-Ende).

const SECTION_SIZE: int = 22
const GAP: int = 10
const MAX_WIDTH: float = 900.0

## Alle Icons in Anzeigereihenfolge (für Fokus-Nachbarn und Tests).
var icons: Array[BuildIcon] = []


func _init(player: Player, centered: bool = true) -> void:
	add_theme_constant_override("separation", GAP)
	_section(tr("RUN_END_WEAPONS"), centered)
	var weapons: HFlowContainer = _flow(centered)
	for weapon: Weapon in player.weapon_slots.get_weapons():
		_add(weapons, BuildIcon.new(weapon.data.texture, weapon.tier, 1, TooltipText.weapon.bind(weapon)))
	var pets: Array[Pet] = player.pet_slots.get_pets()
	if not pets.is_empty():
		_section(tr("RUN_END_PETS"), centered)
		var pet_flow: HFlowContainer = _flow(centered)
		for pet: Pet in pets:
			_add(pet_flow, BuildIcon.new(pet.data.texture, pet.tier, 1, TooltipText.pet.bind(pet)))
	_section(tr("RUN_END_ITEMS"), centered)
	var items: HFlowContainer = _flow(centered)
	for entry: Dictionary in item_stacks():
		var data: ItemData = entry["item"]
		var count: int = entry["count"]
		_add(items, BuildIcon.new(data.icon, data.tier, count, TooltipText.item.bind(data, count)))


## Items des Runs zusammengefasst in Kaufreihenfolge: [{item, count}, ...].
static func item_stacks() -> Array[Dictionary]:
	var counts: Dictionary[StringName, int] = GameState.item_counts()
	var result: Array[Dictionary] = []
	var shown: Dictionary[StringName, bool] = {}
	for data: ItemData in GameState.items:
		if shown.has(data.id):
			continue
		shown[data.id] = true
		result.append({"item": data, "count": counts[data.id]})
	return result


func _section(text: String, centered: bool) -> void:
	var label: Label = UiStyle.make_label(SECTION_SIZE)
	label.text = text
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)


func _flow(centered: bool) -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.custom_minimum_size = Vector2(MAX_WIDTH, 0.0)
	flow.add_theme_constant_override("h_separation", GAP)
	flow.add_theme_constant_override("v_separation", GAP)
	if centered:
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
	add_child(flow)
	return flow


func _add(flow: HFlowContainer, icon: BuildIcon) -> void:
	flow.add_child(icon)
	icons.append(icon)
