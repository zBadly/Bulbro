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
## Sonderzähler der Begleiter je Herkunft (geblockte Projektile, eingesammelte Funken).
var pet_events: Dictionary[StringName, int] = {}
## Kampfzeit (Summe der Wellenzeiten) beim ersten Treffer je Herkunft: DPS zählt erst ab da (Paket 5).
var first_hit_time: Dictionary[StringName, float] = {}
## Run-Ende-Statistik (Phase 15, Paket 5).
var damage_taken: int = 0
var dodges: int = 0
var sparks_spent: int = 0
## Rerolls im Shop und bei Level-ups.
var rerolls: int = 0
## Besiegte Boss-Zyklen im Endlos-Modus (Paket 6).
var boss_cycles: int = 0
## Kampfzeit je abgeschlossener Welle (s); Shop und Pausen zählen nicht.
var wave_times: Array[float] = []
## Schaden je abgeschlossener Welle: Zuwachs der Summe von source_damage (kein eigener Zähler).
var wave_damage: Array[int] = []
## Kampfzeit der laufenden Welle (wird nicht gespeichert, der Fortsetzen-Stand liegt immer im Shop).
var current_wave_time: float = 0.0
var wave_open: bool = false


func record_damage(origin: StringName, amount: int) -> void:
	if origin != &"" and amount > 0:
		if not source_damage.has(origin):
			first_hit_time[origin] = combat_time()
		source_damage[origin] = source_damage.get(origin, 0) + amount


## Neue Welle: eine noch offene (Admin-Sprung ohne Wellenende) wird vorher abgeschlossen.
func begin_wave() -> void:
	end_wave()
	wave_open = true
	current_wave_time = 0.0


func advance(delta: float) -> void:
	if wave_open:
		current_wave_time += delta


## Schließt die laufende Welle ab (Wellenende oder Tod); ohne offene Welle ohne Wirkung.
func end_wave() -> void:
	if not wave_open:
		return
	var before: int = 0
	for amount: int in wave_damage:
		before += amount
	wave_times.append(current_wave_time)
	wave_damage.append(total_damage() - before)
	current_wave_time = 0.0
	wave_open = false


## Bisherige Kampfzeit: alle abgeschlossenen Wellen plus die laufende.
func combat_time() -> float:
	var total: float = current_wave_time
	for seconds: float in wave_times:
		total += seconds
	return total


func total_damage() -> int:
	var total: int = 0
	for origin: StringName in source_damage:
		total += source_damage[origin]
	return total


## Schaden pro Sekunde Kampfzeit seit dem ersten Treffer dieser Herkunft (mindestens `min_time` Sekunden).
func dps_of(origin: StringName, min_time: float) -> float:
	var damage: int = damage_of(origin)
	if damage <= 0:
		return 0.0
	var seconds: float = combat_time() - first_hit_time.get(origin, 0.0)
	return damage / maxf(seconds, min_time)


func record_kill(origin: StringName) -> void:
	if origin != &"":
		source_kills[origin] = source_kills.get(origin, 0) + 1


func kills_of(origin: StringName) -> int:
	return source_kills.get(origin, 0)


func damage_of(origin: StringName) -> int:
	return source_damage.get(origin, 0)


func record_pet_event(origin: StringName, amount: int) -> void:
	pet_events[origin] = pet_events.get(origin, 0) + amount


func pet_events_of(origin: StringName) -> int:
	return pet_events.get(origin, 0)


func to_dict() -> Dictionary:
	var kills: Dictionary = {}
	for weapon_id: StringName in weapon_kills:
		kills[String(weapon_id)] = weapon_kills[weapon_id]
	return {"healed": healed, "max_damage_pct": max_damage_pct, "max_speed_pct": max_speed_pct,
		"max_distinct_weapons": max_distinct_weapons, "primitive_only": primitive_only, "kills": enemies_killed,
		"burn_kills": burn_kills, "max_cursed": max_cursed, "lifesteal_healed": lifesteal_healed,
		"crystals": crystals_destroyed, "weapon_kills": kills, "max_elemental": max_elemental,
		"max_same_weapons": max_same_weapons, "dodge_item_taken": dodge_item_taken, "current_turrets": current_turrets,
		"source_kills": _to_plain(source_kills), "source_damage": _to_plain(source_damage),
		"first_hit_time": _to_plain_float(first_hit_time), "damage_taken": damage_taken, "dodges": dodges,
		"sparks_spent": sparks_spent, "rerolls": rerolls, "boss_cycles": boss_cycles, "wave_times": wave_times.duplicate(),
		"wave_damage": wave_damage.duplicate(), "pet_events": _to_plain(pet_events)}


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
	_from_plain(data.get("pet_events", {}), run.pet_events)
	var first_hits: Dictionary = data.get("first_hit_time", {})
	for key: String in first_hits:
		run.first_hit_time[StringName(key)] = float(first_hits[key])
	run.damage_taken = int(data.get("damage_taken", 0))
	run.dodges = int(data.get("dodges", 0))
	run.sparks_spent = int(data.get("sparks_spent", 0))
	run.rerolls = int(data.get("rerolls", 0))
	run.boss_cycles = int(data.get("boss_cycles", 0))
	for seconds: Variant in data.get("wave_times", []):
		run.wave_times.append(float(seconds))
	for amount: Variant in data.get("wave_damage", []):
		run.wave_damage.append(int(amount))
	return run


static func _to_plain(values: Dictionary[StringName, int]) -> Dictionary:
	var plain: Dictionary = {}
	for key: StringName in values:
		plain[String(key)] = values[key]
	return plain


static func _to_plain_float(values: Dictionary[StringName, float]) -> Dictionary:
	var plain: Dictionary = {}
	for key: StringName in values:
		plain[String(key)] = values[key]
	return plain


static func _from_plain(plain: Dictionary, target: Dictionary[StringName, int]) -> void:
	for key: String in plain:
		target[StringName(key)] = int(plain[key])
