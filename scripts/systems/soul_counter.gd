class_name SoulCounter
extends RefCounted
## Seelenglas des Irrlichts: Kills füllen es bis zur Obergrenze, Beschwörungen verbrauchen nichts.
## Merkt sich den zuletzt getöteten Gegnertyp und wo er starb (dort kehrt der Schattengeist zurück).

var souls: int = 0
var max_souls: int = 0
var last_type: EnemyData
var last_position: Vector2 = Vector2.ZERO


func add(count: int, type: EnemyData, position: Vector2) -> void:
	souls = mini(souls + count, max_souls) if max_souls > 0 else souls + count
	if type != null:
		last_type = type
		last_position = position


func can_summon(min_souls: int) -> bool:
	return souls >= min_souls and last_type != null


## Bonusschaden der Geister: `per_step` pro volle `souls_per_step` Seelen.
func bonus_damage(souls_per_step: int, per_step: float) -> float:
	if souls_per_step <= 0:
		return 0.0
	return floorf(float(souls) / souls_per_step) * per_step


func reset() -> void:
	souls = 0
	last_type = null
	last_position = Vector2.ZERO
