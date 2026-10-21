class_name CurseStatus
extends RefCounted
## Fluch auf einem Gegner (Schwarzlicht): stapelbar, Schaden über Zeit und erhöhter erlittener Schaden.
## Jeder neue Fluch erhöht die Stapel (bis max_stacks) und setzt die Dauer zurück.

const PERCENT: float = 100.0

var stacks: int = 0
var time_left: float = 0.0
var damage_per_second: float = 0.0
## Zusätzlich erlittener Schaden in % pro Stapel.
var bonus_pct_per_stack: float = 0.0
var tick_interval: float = 1.0

var _tick_timer: float = 0.0


func is_active() -> bool:
	return stacks > 0


## Neuer Fluch: +1 Stapel, Dauer neu. Der stärkste Schaden pro Sekunde bleibt.
func apply(dps: float, bonus_pct: float, duration: float, max_stacks: int, interval: float) -> void:
	if not is_active():
		_tick_timer = 0.0
		damage_per_second = 0.0
	stacks = mini(stacks + 1, maxi(1, max_stacks))
	time_left = duration
	damage_per_second = maxf(damage_per_second, dps)
	bonus_pct_per_stack = bonus_pct
	tick_interval = maxf(interval, 0.01)


## Faktor auf eingehenden Schaden (1,15 bei einem Stapel mit 15 %).
func damage_taken_factor() -> float:
	return 1.0 + bonus_pct_per_stack * stacks / PERCENT if is_active() else 1.0


## Läuft die Zeit weiter. Gibt den Schaden zurück, der in diesem Schritt fällig wird (0 = kein Tick).
func tick(delta: float) -> int:
	if not is_active():
		return 0
	var damage: float = 0.0
	_tick_timer += delta
	while _tick_timer >= tick_interval:
		_tick_timer -= tick_interval
		damage += damage_per_second * tick_interval * stacks
	time_left -= delta
	if time_left <= 0.0:
		clear()
	return roundi(damage)


func clear() -> void:
	stacks = 0
	time_left = 0.0
	_tick_timer = 0.0
