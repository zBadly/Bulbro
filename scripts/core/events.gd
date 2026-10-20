extends Node
## Globaler Signalbus (Autoload "Events").
## Systeme kommunizieren über diese Signale statt über direkte Referenzen.
## Signale werden hier nur deklariert und von anderen Skripten emittiert.

@warning_ignore("unused_signal")
signal run_started(seed_value: int)
@warning_ignore("unused_signal")
signal run_ended(victory: bool)
@warning_ignore("unused_signal")
signal wave_started(wave_number: int)
@warning_ignore("unused_signal")
signal wave_ended(wave_number: int)
@warning_ignore("unused_signal")
signal pause_toggled(is_paused: bool)
@warning_ignore("unused_signal")
signal player_died
@warning_ignore("unused_signal")
signal enemy_killed(data: EnemyData, position: Vector2)
