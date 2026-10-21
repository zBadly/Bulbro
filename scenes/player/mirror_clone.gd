class_name MirrorClone
extends Node2D
## Spiegelbild (Spiegelkugel): folgt dem Spieler mit Abstand und trägt Kopien seiner Waffen.
## Die Kopien machen weniger Schaden, haben keinen Lebensraub und lösen keine Angriffs-Effekte aus.

const STATUS: StatusConfig = preload("res://data/config/status_config.tres")

var player: Player
var weapon_slots: WeaponSlots

var _visual: Node2D
var _sprite: Sprite2D


func setup(p_player: Player, damage_factor: float) -> void:
	player = p_player
	global_position = player.global_position + Vector2.LEFT * STATUS.mirror_follow_distance
	_visual = Node2D.new()
	add_child(_visual)
	_sprite = Sprite2D.new()
	_sprite.texture = player.get_body_texture()
	_sprite.offset = Vector2(0.0, -_sprite.texture.get_height() * 0.5)
	_sprite.modulate = STATUS.mirror_tint
	_visual.add_child(_sprite)
	weapon_slots = WeaponSlots.new()
	weapon_slots.player = player
	weapon_slots.max_slots = player.weapon_slots.max_slots
	weapon_slots.orbit_radius = player.weapon_slots.orbit_radius
	weapon_slots.position = player.weapon_slots.position
	add_child(weapon_slots)
	for weapon: Weapon in player.weapon_slots.get_weapons():
		var copy: Weapon = weapon_slots.add_weapon(weapon.data, weapon.tier)
		copy.is_clone = true
		copy.damage_factor = damage_factor
		copy.modulate = STATUS.mirror_tint
	Juice.idle_bob(_visual)


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead:
		return
	var to_player: Vector2 = player.global_position - global_position
	var excess: float = to_player.length() - STATUS.mirror_follow_distance
	if excess <= 0.0:
		return
	var step: float = minf(excess, maxf(STATUS.mirror_follow_speed, player.get_move_speed()) * delta)
	var move: Vector2 = to_player.normalized() * step
	global_position += move
	_sprite.flip_h = move.x < 0.0
