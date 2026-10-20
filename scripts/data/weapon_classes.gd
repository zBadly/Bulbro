class_name WeaponClasses
extends RefCounted
## Waffenklassen (GDD Abschnitt 8). Set-Boni folgen in einer späteren Phase.

const BLADE: StringName = &"blade"
const BLUNT: StringName = &"blunt"
const PRECISE: StringName = &"precise"
const HEAVY: StringName = &"heavy"
const PRIMITIVE: StringName = &"primitive"
const UNARMED: StringName = &"unarmed"
const ELEMENTAL: StringName = &"elemental"
const TOOL: StringName = &"tool"
const EXPLOSIVE: StringName = &"explosive"
const GUN: StringName = &"gun"
const MEDICAL: StringName = &"medical"
const ETHEREAL: StringName = &"ethereal"
const SUPPORT: StringName = &"support"

const ALL: Array[StringName] = [
	BLADE, BLUNT, PRECISE, HEAVY, PRIMITIVE, UNARMED, ELEMENTAL, TOOL, EXPLOSIVE, GUN, MEDICAL, ETHEREAL, SUPPORT,
]


static func label_key(weapon_class: StringName) -> String:
	return "CLASS_" + String(weapon_class).to_upper()
