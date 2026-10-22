class_name AdminState
extends RefCounted
## Admin-Modus eines Runs (GameState.admin). `used` wird bei der ersten ausgeführten Admin-Aktion gesetzt;
## danach zählt der Run nicht mehr für Freischaltungen, Achievements und Gesamtstatistiken (auch nach Fortsetzen).

const GAME_SPEEDS: Array[float] = [0.5, 1.0, 2.0, 4.0]
const NORMAL_SPEED: float = 1.0
const DAMAGE_BOOST: float = 10.0

var used: bool = false
## Treffer kommen an, ziehen aber keine HP ab (im Gegensatz zu Unverwundbar).
var infinite_hp: bool = false
## Faktor auf jeden Schaden an Gegnern (1 oder DAMAGE_BOOST).
var damage_factor: float = 1.0
var shop_free: bool = false
var free_reroll: bool = false
## Wellenzeit steht (keine Gruppen-Spawns, kein Wellenende per Timer).
var time_frozen: bool = false
var game_speed: float = NORMAL_SPEED
var show_hitboxes: bool = false


## Darf der Admin-Modus genutzt werden (Schalter in den Optionen unter "Erweitert")?
static func is_enabled() -> bool:
	return SaveManager.get_option(SaveManager.ADMIN_MODE_KEY, false)
