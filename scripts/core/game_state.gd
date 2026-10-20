extends Node
## Zustand des aktuellen Runs (Autoload "GameState").
## Hält den Run-RNG mit Seed, damit Runs für Debugging reproduzierbar sind, sowie Funken, Beutel, XP und Level.

var run_seed: int = 0
var current_wave: int = 0
var is_run_active: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Währung (1 Funke = 1 Währung + 1 XP).
var sparks: int = 0
## Nicht aufgesammelte Funken der letzten Welle; jeder neue Funke gibt +1 daraus dazu.
var bag: int = 0
var xp: float = 0.0
var level: int = 0
## Level-ups, die am Wellenende abgearbeitet werden.
var pending_level_ups: int = 0
var crates_this_wave: int = 0
## Eingesammelte Kartons, die am Wellenende geöffnet werden.
var pending_crates: int = 0
var total_sparks_collected: int = 0


## Startet einen neuen Run. Ohne Seed wird ein zufälliger gewählt.
func start_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
		run_seed = rng.seed
	else:
		run_seed = seed_value
	rng.seed = run_seed
	current_wave = 0
	sparks = 0
	bag = 0
	xp = 0.0
	level = 0
	pending_level_ups = 0
	crates_this_wave = 0
	pending_crates = 0
	total_sparks_collected = 0
	is_run_active = true
	Events.run_started.emit(run_seed)


func end_run(victory: bool) -> void:
	is_run_active = false
	Events.run_ended.emit(victory)


func xp_needed() -> float:
	return Economy.xp_for_level(level)


## Ein Funke wurde aufgesammelt. Gibt den tatsächlichen Wert inkl. Beutel-Bonus zurück.
func collect_spark(value: int, xp_gain_pct: float) -> int:
	var bonus: int = mini(bag, value)
	bag -= bonus
	var total: int = value + bonus
	total_sparks_collected += total
	add_sparks(total)
	add_xp(Economy.xp_gain(total, xp_gain_pct))
	return total


func add_sparks(amount: int) -> void:
	sparks = maxi(0, sparks + amount)
	Events.sparks_changed.emit(sparks, bag)


func add_to_bag(amount: int) -> void:
	bag += amount
	Events.sparks_changed.emit(sparks, bag)


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending_level_ups += 1
		Events.level_up.emit(level)
	Events.xp_changed.emit(xp, xp_needed(), level)


func add_crate() -> void:
	pending_crates += 1
	Events.crate_collected.emit(pending_crates)
