class_name SpellCycleEffect
extends ItemEffect
## Kronleuchter: Jeder `every_nth`. Angriff jeder Waffe wirkt zusätzlich einen Zauber am Ziel.
## Die Zauber kommen reihum aus `spells` (z. B. Feuerball, Frostnova, Kettenblitz).

const COUNTS_KEY: String = "counts"
const NEXT_KEY: String = "next"

@export var every_nth: int = 1
@export var spells: Array[EffectAction] = []


func is_trigger() -> bool:
	return true


func on_weapon_attack(ctx: EffectContext, entry: TriggerEntry, weapon: Weapon, target: Damageable) -> void:
	if target == null or not is_instance_valid(target) or spells.is_empty():
		return
	var counts: Dictionary = entry.state.get_or_add(COUNTS_KEY, {})
	var id: int = weapon.get_instance_id()
	var count: int = int(counts.get(id, 0)) + 1
	counts[id] = count
	if count % maxi(1, every_nth) != 0:
		return
	var index: int = int(entry.state.get(NEXT_KEY, 0))
	entry.state[NEXT_KEY] = (index + 1) % spells.size()
	spells[index].execute(ctx, target.get_hit_position())


func describe() -> PackedStringArray:
	var names: PackedStringArray = []
	for spell: EffectAction in spells:
		names.append(spell.describe())
	return [TextFormat.t("EFFECT_SPELL_CYCLE") % [every_nth, " / ".join(names)]]
