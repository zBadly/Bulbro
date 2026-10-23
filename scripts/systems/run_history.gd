class_name RunHistory
extends RefCounted
## Kompakte Zusammenfassung eines Runs für den Spielstand (Phase 15, Paket 5; Statistik-Bildschirm in Paket 9).
## Admin-Runs werden nicht gespeichert. Endlos nach dem Sieg aktualisiert den Eintrag desselben Runs.

const RESULT_VICTORY: String = "victory"
const RESULT_DEFEAT: String = "defeat"
## Kampfzeit im Eintrag auf Zehntelsekunden gerundet.
const TIME_STEP: float = 0.1


## Eintrag für den aktuellen Run. Ein Tod im Endlos-Modus bleibt ein Sieg (mit erreichter Endlos-Welle).
static func make_entry(victory: bool) -> Dictionary:
	var run: RunStats = GameState.run_stats
	var top: Array = []
	for row: RunReport.Row in RunReport.top_sources(run, RunReport.CONFIG.history_top_sources):
		top.append({"source": String(row.origin), "damage": row.damage, "kills": row.kills})
	return {
		"id": GameState.run_id,
		"character": String(GameState.character.id) if GameState.character != null else "",
		"difficulty": GameState.difficulty.level if GameState.difficulty != null else 0,
		"result": RESULT_VICTORY if victory or GameState.endless else RESULT_DEFEAT,
		"wave": GameState.current_wave,
		"endless_wave": GameState.endless_level(),
		"boss_cycles": run.boss_cycles,
		"date": int(Time.get_unix_time_from_system()),
		"time": snappedf(run.combat_time(), TIME_STEP),
		"level": GameState.level,
		"kills": run.enemies_killed,
		"top_sources": top,
	}


static func record(victory: bool) -> void:
	if GameState.admin.used:
		return
	SaveManager.record_run_history(make_entry(victory), RunReport.CONFIG.history_size)
