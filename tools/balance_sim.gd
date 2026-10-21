extends Node
## Balancing-Simulator: Gegner-HP pro Welle gegen die DPS typischer Builds (BalanceModel).
## Aufruf (headless, aus dem Projektordner):
##   godot --headless --path . res://tools/balance_sim.tscn                 -> Tabelle und Vorschläge (Spannung 0)
##   godot --headless --path . res://tools/balance_sim.tscn -- 3            -> für Spannung 3
##   godot --headless --path . res://tools/balance_sim.tscn -- 0 --apply    -> Vorschläge in die Wellen-.tres schreiben

const WAVE_DIR: String = "res://data/waves"
const WEAPON_DIR: String = "res://data/weapons"
const DIFFICULTY_PATH: String = "res://data/difficulties/spannung_%d.tres"
const APPLY_FLAG: String = "--apply"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level: int = int(args[0]) if not args.is_empty() and args[0].is_valid_int() else 0
	var apply: bool = APPLY_FLAG in args
	var difficulty: DifficultyData = load(DIFFICULTY_PATH % level)
	var weapons: Dictionary = {}
	for file: String in DirAccess.get_files_at(WEAPON_DIR):
		if file.get_extension() == "tres":
			var weapon: WeaponData = load(WEAPON_DIR.path_join(file))
			weapons[String(weapon.id)] = weapon
	var waves: Array[WaveData] = []
	for file: String in DirAccess.get_files_at(WAVE_DIR):
		if file.get_extension() == "tres":
			waves.append(load(WAVE_DIR.path_join(file)))
	waves.sort_custom(func(a: WaveData, b: WaveData) -> bool: return a.wave_number < b.wave_number)

	print("BULBRO Balancing-Simulation – Spannung %d (Build-DPS / benötigte DPS; ok = %.1f bis %.1f)" % [
		level, BalanceModel.TOO_HARD, BalanceModel.TOO_EASY])
	var header: String = "%5s | %5s | %6s | %9s | %8s" % ["Welle", "Dauer", "Gegner", "HP gesamt", "DPS nötig"]
	for build: String in BalanceModel.BUILDS:
		header += " | %11s" % build
	header += " | %-10s | %s" % ["Bewertung", "Vorschlag"]
	print(header)
	print("-".repeat(header.length()))
	var suggestions: Dictionary = {}
	for wave: WaveData in waves:
		if wave.is_boss:
			print("%5d | Bosswelle (endet mit dem Boss) – nicht simuliert" % wave.wave_number)
			continue
		var load_info: Dictionary = BalanceModel.wave_load(wave, difficulty)
		var line: String = "%5d | %5.0f | %6.0f | %9.0f | %8.1f" % [wave.wave_number, wave.duration, load_info["count"], load_info["hp"], load_info["required_dps"]]
		var ratios: Array[float] = []
		for build: String in BalanceModel.BUILDS:
			var dps: float = BalanceModel.build_dps(BalanceModel.BUILDS[build], wave.wave_number, weapons)
			var ratio: float = dps / maxf(load_info["required_dps"], 0.01)
			ratios.append(ratio)
			line += " | %5.0f x%4.2f" % [dps, ratio]
		var average: float = ratios.reduce(func(s: float, r: float) -> float: return s + r, 0.0) / ratios.size()
		var verdict: String = BalanceModel.rating(average)
		var proposal: String = ""
		if verdict != "ok":
			var factor: float = BalanceModel.interval_factor(average)
			suggestions[wave] = factor
			proposal = "Spawn-Intervalle x%.2f (%s Gegner)" % [factor, "weniger" if factor > 1.0 else "mehr"]
		print(line + " | %-10s | %s" % [verdict, proposal])

	print("")
	if suggestions.is_empty():
		print("Keine Auffälligkeiten.")
	elif apply:
		for wave: WaveData in suggestions:
			for group: SpawnGroupData in wave.groups:
				group.interval = snappedf(group.interval * suggestions[wave], 0.05)
			print("Welle %d: %s" % [wave.wave_number, error_string(ResourceSaver.save(wave, wave.resource_path))])
		print("%d Wellen angepasst." % suggestions.size())
	else:
		print("%d Wellen auffällig. Mit '%s' werden die Vorschläge in die .tres geschrieben." % [suggestions.size(), APPLY_FLAG])
	get_tree().quit()
