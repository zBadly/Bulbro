class_name UpgradeData
extends Resource
## Level-up-Upgrade (GDD Abschnitt 5): ein Stat mit eigenem Wert pro Tier I-IV.

@export var id: StringName
@export var stat: StringName
## Index 0 = Tier I ... Index 3 = Tier IV.
@export var tier_values: Array[float] = []
@export var icon: Texture2D


func value_for_tier(tier: int) -> float:
	return tier_values[clampi(tier, 1, tier_values.size()) - 1]


func modifier_for_tier(tier: int) -> StatModifier:
	return StatModifier.create(stat, value_for_tier(tier))
