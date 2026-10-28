class_name Pet
extends CharacterBody2D
## Begleiter (Phase 15, Paket 8): folgt dem Spieler mit leichter Verzögerung zu seinem Ruheplatz und weicht anderen
## Begleitern aus. Unverwundbar; steht wie die Schattengeister auf der Verbündeten-Ebene und nicht in der Gegnergruppe,
## daher zielen Waffen nicht darauf und er zählt nicht zum Gegnerlimit. Was er tut, steht im PetBehavior seiner Daten.

const CONFIG: PetConfig = preload("res://data/config/pet_config.tres")
const GROUP: StringName = &"pets"

var data: PetData
var tier: int = WeaponData.MIN_TIER
var player: Player
var slots: PetSlots
## Ruheplatz (Index in PetConfig.follow_offsets).
var slot_index: int = 0
## Zustand des Verhaltens (Abklingzeiten, Ziele, erzeugte Knoten).
var state: Dictionary = {}

var _time: float = 0.0

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite


func setup(p_data: PetData, p_tier: int, p_player: Player, p_slots: PetSlots) -> void:
	data = p_data
	tier = p_tier
	player = p_player
	slots = p_slots


func _ready() -> void:
	add_to_group(GROUP)
	sprite.texture = data.texture
	sprite.offset = Vector2(0.0, -data.texture.get_height() * 0.5)
	global_position = rest_point()
	data.behavior.start(self)


## Herkunft für die Run-Statistik ("pet/<id>").
func get_origin() -> StringName:
	return DamageSource.pet(data.id)


func get_tier_stats() -> PetTierStats:
	return data.get_tier(tier)


## Körpermitte in Weltkoordinaten (Ursprung von Schüssen und Wirkradien).
func get_center() -> Vector2:
	return global_position + Vector2(0.0, -data.texture.get_height() * 0.5)


## Ruheplatz neben dem Spieler (ohne Verzögerung).
func rest_point() -> Vector2:
	if player == null:
		return global_position
	var offsets: Array[Vector2] = CONFIG.follow_offsets
	return player.global_position + (offsets[slot_index % offsets.size()] if not offsets.is_empty() else Vector2.ZERO)


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead:
		return
	_time += delta
	var moved_itself: bool = false
	if GameState.phase == GameState.Phase.WAVE:
		moved_itself = data.behavior.tick(self, delta)
	if not moved_itself:
		_follow(delta)


## Mit Verzögerung zum Ruheplatz (plus Versatz des Verhaltens) und von anderen Begleitern weg.
func _follow(delta: float) -> void:
	var target: Vector2 = rest_point() + data.behavior.follow_offset(self, _time)
	var weight: float = 1.0 - exp(-CONFIG.follow_sharpness * delta)
	move_by((target - global_position) * weight, delta)


## Bewegt den Begleiter, hält Abstand zu den anderen und spielt die Bewegungsanimation.
func move_by(step: Vector2, delta: float) -> void:
	var before: Vector2 = global_position
	global_position += step
	_separate()
	if player.arena_bounds.has_area():
		global_position = global_position.clamp(player.arena_bounds.position, player.arena_bounds.end)
	data.behavior.animate_move(self, (global_position - before) / maxf(delta, 0.0001), delta)


## Zu nahe Begleiter schieben sich je zur Hälfte auseinander.
func _separate() -> void:
	if slots == null:
		return
	for other: Pet in slots.get_pets():
		if other == self:
			continue
		var away: Vector2 = global_position - other.global_position
		var distance: float = away.length()
		if distance >= CONFIG.separation_distance:
			continue
		var direction: Vector2 = away / distance if distance > 0.0 else Vector2.from_angle(PI * slot_index)
		global_position += direction * (CONFIG.separation_distance - distance) * 0.5


## Entfernen (Ersetzen, Kombinieren, Recyceln): Verhalten räumt auf, dann verschwindet der Begleiter.
func dismiss() -> void:
	data.behavior.stop(self)
	queue_free()
