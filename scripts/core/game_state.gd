extends Node
## Zustand des aktuellen Runs (Autoload "GameState").
## Hält den Run-RNG mit Seed, damit Runs für Debugging reproduzierbar sind.

var run_seed: int = 0
var current_wave: int = 0
var is_run_active: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Startet einen neuen Run. Ohne Seed wird ein zufälliger gewählt.
func start_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
		run_seed = rng.seed
	else:
		run_seed = seed_value
	rng.seed = run_seed
	current_wave = 0
	is_run_active = true
	Events.run_started.emit(run_seed)


func end_run(victory: bool) -> void:
	is_run_active = false
	Events.run_ended.emit(victory)
