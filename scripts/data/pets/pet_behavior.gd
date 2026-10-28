class_name PetBehavior
extends Resource
## Was ein Begleiter tut (Baustein der PetData, wie Effekte bei Items). Zustand pro Exemplar liegt in `Pet.state`,
## nie in der Resource. Ohne eigenes Verhalten folgt der Begleiter dem Spieler und hüpft.


## Begleiter ist erschienen: Animation starten, Knoten anlegen.
func start(pet: Pet) -> void:
	Juice.idle_bob(pet.visual)


## Begleiter wird entfernt (Ersetzen, Kombinieren, Recyceln): erzeugte Knoten aufräumen.
func stop(_pet: Pet) -> void:
	pass


## Während einer Welle jeden Physik-Frame. true = der Begleiter hat sich selbst bewegt, sonst folgt er dem Spieler.
func tick(_pet: Pet, _delta: float) -> bool:
	return false


## Versatz zum Ruheplatz beim Folgen (z. B. Kreisen), `time` = Sekunden seit dem Erscheinen.
func follow_offset(_pet: Pet, _time: float) -> Vector2:
	return Vector2.ZERO


## Animation beim Bewegen (jeden Frame mit der aktuellen Geschwindigkeit).
func animate_move(pet: Pet, velocity: Vector2, _delta: float) -> void:
	Juice.walk_tilt(pet.visual, velocity)


## Die Waffen des Spielers haben sich geändert (Mini-Birne).
func on_weapons_changed(_pet: Pet) -> void:
	pass


## Wirkung im Tier (BBCode-Zeilen) für Shop-Karte und Lexikon.
func describe(_stats: PetTierStats) -> PackedStringArray:
	return []


## Aktuelle Werte eines vorhandenen Begleiters für den Tooltip (z. B. Schaden mit allen Stats).
func status_lines(_pet: Pet) -> PackedStringArray:
	return []


## Schaden mit den Stats des Spielers: Basis + Skalierung, mit Schaden-%. Mindestens 1.
static func damage(stats: PetTierStats, player_stats: StatSystem) -> int:
	return CombatMath.weapon_damage(stats.base_damage, CombatMath.scaling_bonus(stats.scalings, player_stats),
		player_stats.get_stat(Stats.DAMAGE_PCT), 1.0)


## Sekunden wie bei Waffen-Abklingzeiten auf zwei Stellen, ohne überflüssige Nullen (0.92, 2.6, 3).
static func seconds(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return ("%.2f" % value).rstrip("0")
