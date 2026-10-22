class_name RunStats
extends RefCounted
## Werte eines Runs für Freischaltungen und die Build-Übersicht am Run-Ende.

var healed: float = 0.0
var max_damage_pct: float = 0.0
var max_speed_pct: float = 0.0
var max_distinct_weapons: int = 0
var primitive_only: bool = true
var enemies_killed: int = 0
## Kills durch Brand-Ticks (Zündkerze).
var burn_kills: int = 0
## Höchstzahl gleichzeitig verfluchter Gegner (Schwarzlicht).
var max_cursed: int = 0
## Durch Lebensraub geheilte HP (Vampirbirne).
var lifesteal_healed: float = 0.0
var crystals_destroyed: int = 0
## Kills pro Waffen-ID (Schwarzlicht: Voodoo-Nadel).
var weapon_kills: Dictionary[StringName, int] = {}
## Höchster Strom-Wert in diesem Run (Kronleuchter).
var max_elemental: float = 0.0
## Höchste Zahl gleicher Waffen beim Ende einer Welle (Spiegelkugel).
var max_same_weapons: int = 0
## Ein Item mit positivem Ausweichen genommen (Stroboskop).
var dodge_item_taken: bool = false
## Gerade stehende Lampentürme; bleibt nach dem Wellenende stehen, damit das Run-Ende ihn kennt (Drohnenleuchte).
var current_turrets: int = 0
## Kills und verursachter Schaden je Herkunft (DamageSource, z. B. "weapon/ast", "item/supernova", "ally").
## Grundlage für Tooltips und die Run-Statistik.
var source_kills: Dictionary[StringName, int] = {}
var source_damage: Dictionary[StringName, int] = {}


func record_damage(origin: StringName, amount: int) -> void:
	if origin != &"" and amount > 0:
		source_damage[origin] = source_damage.get(origin, 0) + amount


func record_kill(origin: StringName) -> void:
	if origin != &"":
		source_kills[origin] = source_kills.get(origin, 0) + 1


func kills_of(origin: StringName) -> int:
	return source_kills.get(origin, 0)


func damage_of(origin: StringName) -> int:
	return source_damage.get(origin, 0)


func to_dict() -> Dictionary:
	var kills: Dictionary = {}
	for weapon_id: StringName in weapon_kills:
		kills[String(weapon_id)] = weapon_kills[weapon_id]
	return {"healed": healed, "max_damage_pct": max_damage_pct, "max_speed_pct": max_speed_pct,
		"max_distinct_weapons": max_distinct_weapons, "primitive_only": primitive_only, "kills": enemies_killed,
		"burn_kills": burn_kills, "max_cursed": max_cursed, "lifesteal_healed": lifesteal_healed,
		"crystals": crystals_destroyed, "weapon_kills": kills, "max_elemental": max_elemental,
		"max_same_weapons": max_same_weapons, "dodge_item_taken": dodge_item_taken, "current_turrets": current_turrets,
		"source_kills": _to_plain(source_kills), "source_damage": _to_plain(source_damage)}


static func from_dict(data: Dictionary) -> RunStats:
	var run: RunStats = RunStats.new()
	run.healed = float(data.get("healed", 0.0))
	run.max_damage_pct = float(data.get("max_damage_pct", 0.0))
	run.max_speed_pct = float(data.get("max_speed_pct", 0.0))
	run.max_distinct_weapons = int(data.get("max_distinct_weapons", 0))
	run.primitive_only = bool(data.get("primitive_only", true))
	run.enemies_killed = int(data.get("kills", 0))
	run.burn_kills = int(data.get("burn_kills", 0))
	run.max_cursed = int(data.get("max_cursed", 0))
	run.lifesteal_healed = float(data.get("lifesteal_healed", 0.0))
	run.crystals_destroyed = int(data.get("crystals", 0))
	var kills: Dictionary = data.get("weapon_kills", {})
	for weapon_id: String in kills:
		run.weapon_kills[StringName(weapon_id)] = int(kills[weapon_id])
	run.max_elemental = float(data.get("max_elemental", 0.0))
	run.max_same_weapons = int(data.get("max_same_weapons", 0))
	run.dodge_item_taken = bool(data.get("dodge_item_taken", false))
	run.current_turrets = int(data.get("current_turrets", 0))
	_from_plain(data.get("source_kills", {}), run.source_kills)
	_from_plain(data.get("source_damage", {}), run.source_damage)
	return run


static func _to_plain(values: Dictionary[StringName, int]) -> Dictionary:
	var plain: Dictionary = {}
	for key: StringName in values:
		plain[String(key)] = values[key]
	return plain


static func _from_plain(plain: Dictionary, target: Dictionary[StringName, int]) -> void:
	for key: String in plain:
		target[StringName(key)] = int(plain[key])
