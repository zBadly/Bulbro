class_name RunStats
extends RefCounted
## Werte eines Runs für Freischaltungen und die Build-Übersicht am Run-Ende.

var healed: float = 0.0
var max_damage_pct: float = 0.0
var max_speed_pct: float = 0.0
var max_distinct_weapons: int = 0
var primitive_only: bool = true
var enemies_killed: int = 0
## Kills durch Brand-Ticks (Zündkerze).
var burn_kills: int = 0
## Höchstzahl gleichzeitig verfluchter Gegner (Schwarzlicht).
var max_cursed: int = 0
## Durch Lebensraub geheilte HP (Vampirbirne).
var lifesteal_healed: float = 0.0
