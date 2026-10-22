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
signal boss_spawned(enemy: Enemy)
@warning_ignore("unused_signal")
signal options_changed
@warning_ignore("unused_signal")
signal challenge_completed(challenge: ChallengeData)
@warning_ignore("unused_signal")
signal enemy_killed(data: EnemyData, position: Vector2, info: DamageInfo)
## Ein Gegner hat Schaden genommen (`amount` ohne Overkill); `origin` siehe DamageSource.
@warning_ignore("unused_signal")
signal enemy_damaged(origin: StringName, amount: int)
@warning_ignore("unused_signal")
signal sparks_changed(sparks: int, bag: int)
@warning_ignore("unused_signal")
signal xp_changed(xp: float, needed: float, level: int)
@warning_ignore("unused_signal")
signal level_up(new_level: int)
@warning_ignore("unused_signal")
signal crate_collected(pending: int)
@warning_ignore("unused_signal")
signal crystal_destroyed(position: Vector2)
@warning_ignore("unused_signal")
signal run_phase_changed(phase: int)
@warning_ignore("unused_signal")
signal item_added(item: ItemData)
@warning_ignore("unused_signal")
signal spark_collected
## Ein Gegner ist gestorben, während er brannte (Zündkerze: Explosion).
@warning_ignore("unused_signal")
signal burning_enemy_killed(position: Vector2)
## Ein Effekt möchte eine Struktur bauen (Lichtranke); die Arena erzeugt sie.
@warning_ignore("unused_signal")
signal structure_requested(data: StructureData, tier: int, position: Vector2)
