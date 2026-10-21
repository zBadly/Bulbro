class_name ProjectileSpec
extends RefCounted
## Alles, was ein Spieler-Projektil beim Abschuss braucht.

var texture: Texture2D
var speed: float = 0.0
var max_range: float = 0.0
var info: DamageInfo
var piercing: int = 0
var bounces: int = 0
var chain_count: int = 0
var chain_range: float = 0.0
var explosion_radius: float = 0.0
var homing_turn_deg: float = 0.0
## Zersplittert beim ersten Treffer in so viele kleinere Projektile (Kristallstab).
var split_count: int = 0
var split_damage_pct: float = 0.0
var split_texture: Texture2D
## Für Lebensraub, Heilung und Explosions-Stats; null bei Strukturen ohne Spielerbezug.
var player: Player
## Strukturen lösen keinen Lebensraub aus.
var lifesteal: bool = true
