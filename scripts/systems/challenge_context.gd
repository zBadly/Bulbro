class_name ChallengeContext
extends RefCounted
## Alles, was eine Freischaltbedingung zum Prüfen braucht: Werte des laufenden Runs und Gesamtwerte über alle Runs.

var run: RunStats = RunStats.new()
var max_structures: int = 0
var current_wave: int = 0
var victory: bool = false
var at_run_end: bool = false
var character_id: StringName = &""
## Gesamtwerte (Statistik-Schlüssel -> Wert) inklusive der noch nicht gespeicherten Zuwächse dieses Runs.
var totals: Dictionary[String, int] = {}
