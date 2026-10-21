class_name SlowStatus
extends RefCounted
## Verlangsamung eines Gegners: Tempo x factor für eine Dauer. Faktor 0 = eingefroren bzw. festgehalten
## (kein Laufen, kein Angriff, kein Kontaktschaden). Die stärkere Verlangsamung gewinnt.

var factor: float = 1.0
var time_left: float = 0.0


func is_active() -> bool:
	return time_left > 0.0


## Eingefroren oder festgehalten.
func is_stopped() -> bool:
	return is_active() and factor <= 0.0


func apply(p_factor: float, duration: float) -> void:
	if duration <= 0.0:
		return
	if not is_active() or p_factor < factor:
		factor = clampf(p_factor, 0.0, 1.0)
		time_left = duration
	elif is_equal_approx(p_factor, factor):
		time_left = maxf(time_left, duration)


func speed_factor() -> float:
	return factor if is_active() else 1.0


func tick(delta: float) -> void:
	if time_left > 0.0:
		time_left -= delta
		if time_left <= 0.0:
			clear()


func clear() -> void:
	factor = 1.0
	time_left = 0.0
