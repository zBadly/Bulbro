class_name TowerConfig
extends Resource
## Türme und Minen (Phase 15, Paket 8): Platzierung zu Wellenbeginn und Obergrenzen.

## Türme landen zufällig in einem Ring um den Spieler (Innen- und Außenradius, px).
@export var ring_min_radius: float = 0.0
@export var ring_max_radius: float = 0.0
## Mindestabstand zwischen zwei Türmen (px).
@export var min_spacing: float = 0.0
## Versuche je Turm, einen freien Platz zu finden; danach nimmt er den Platz mit dem größten Abstand.
@export var placement_tries: int = 0
## Abstand zum Arenarand (px).
@export var edge_margin: float = 0.0
## Höchstzahl gleichzeitiger Türme (Waffen-Lampentürme zuerst, dann Item-Türme in Kaufreihenfolge).
@export var max_towers: int = 0
## Höchstzahl gleichzeitiger Minen; beim Überschreiten verschwindet die älteste.
@export var max_mines: int = 0
## Wie oft eine scharfe Mine nach Gegnern sucht (s).
@export var mine_check_interval: float = 0.0

@export_group("Darstellung")
@export var heal_number_color: Color = Color.WHITE
@export var heal_number_font_size: int = 0
## Versatz der Heilzahl zur Körpermitte (über dem Kopf, damit der Spieler sie nicht verdeckt).
@export var heal_number_offset: Vector2 = Vector2.ZERO
## Deckkraft der Aura-Fläche am Boden und Breite des Rands.
@export var aura_fill_alpha: float = 0.0
@export var aura_ring_width: float = 0.0
## Wie lange ein Flammenstrahl sichtbar bleibt (s).
@export var flame_visible_time: float = 0.0
@export var flame_color: Color = Color.WHITE
@export var flame_core_color: Color = Color.WHITE
