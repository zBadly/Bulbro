class_name PetData
extends Resource
## Begleiter (Phase 15, Paket 8): eigener Item-Typ mit Tiers I-IV wie Waffen. Im Shop kaufbar und kombinierbar
## (2 gleiche gleichen Tiers -> nächstes Tier), höchstens PetConfig.max_pets gleichzeitig.
## Was der Begleiter tut, steht im `behavior`; die Zahlen je Tier in `tiers`.

@export var id: StringName
@export var name_key: String = ""
@export var texture: Texture2D
## Werte je Tier (Index 0 = Tier I).
@export var tiers: Array[PetTierStats] = []
@export var behavior: PetBehavior
## Für die Gewichtung im Shop nach Charakter-Vorlieben.
@export var tags: Array[StringName] = []
## Lexikon: Übersetzungsschlüssel eines witzigen Satzes.
@export var lore_text: String = ""


func get_tier(tier: int) -> PetTierStats:
	return tiers[clampi(tier, WeaponData.MIN_TIER, tiers.size()) - 1]


## Beschreibung (BBCode) für Shop-Karte und Lexikon: Wirkung im Tier, darunter die Begleiter-Regel.
func get_description(tier: int) -> String:
	var lines: PackedStringArray = behavior.describe(get_tier(tier))
	lines.append("[color=%s]%s[/color]" % [TooltipText.MUTED_COLOR, TextFormat.t("PET_RULE") % PetSlots.CONFIG.max_pets])
	return "\n".join(lines)
