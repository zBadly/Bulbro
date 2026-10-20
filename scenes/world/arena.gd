class_name Arena
extends Node2D
## Rechteckige Arena mit kachelbarem Boden, sichtbarem Rand und Kamera, die dem Spieler folgt.

const LIGHTING_SECTION: String = "options"
const LIGHTING_KEY: String = "lighting"
const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const WEAPON_CATEGORY: String = "weapons"

@export var config: ArenaConfig

@onready var _floor: Sprite2D = $Floor
@onready var _darkness: CanvasModulate = $Darkness
@onready var _camera: Camera2D = $Camera
@onready var player: Player = $Entities/Player
@onready var _projectile_pool: ObjectPool = $Pools/PlayerProjectiles
@onready var _damage_number_pool: ObjectPool = $Pools/DamageNumbers

var _debug_weapon_index: int = 0


func _ready() -> void:
	GameState.start_run()
	_projectile_pool.prewarm(COMBAT.projectile_pool_size)
	_damage_number_pool.prewarm(COMBAT.damage_number_pool_size)
	var rect: Rect2 = config.get_rect()
	_floor.region_rect = Rect2(Vector2.ZERO, config.size)
	_floor.position = rect.get_center()
	player.arena_bounds = rect

	var lighting: bool = SaveManager.get_value(LIGHTING_SECTION, LIGHTING_KEY, true)
	_darkness.color = config.darkness_color
	_darkness.visible = lighting

	_camera.zoom = Vector2.ONE * config.camera_zoom
	_camera.position_smoothing_speed = config.camera_smoothing_speed
	_camera.limit_left = floori(rect.position.x - config.camera_margin)
	_camera.limit_top = floori(rect.position.y - config.camera_margin)
	_camera.limit_right = ceili(rect.end.x + config.camera_margin)
	_camera.limit_bottom = ceili(rect.end.y + config.camera_margin)
	_camera.global_position = player.global_position
	_camera.reset_smoothing()
	queue_redraw()


func _process(_delta: float) -> void:
	_camera.global_position = player.global_position


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_add_weapon"):
		_debug_add_weapon()
		get_viewport().set_input_as_handled()


## Debug (F4): fügt reihum die nächste Waffe aus res://data/weapons hinzu.
func _debug_add_weapon() -> void:
	var weapons: Array[Resource] = DataRegistry.get_all(WEAPON_CATEGORY)
	if weapons.is_empty():
		return
	weapons.sort_custom(func(a: Resource, b: Resource) -> bool: return String((a as WeaponData).id) < String((b as WeaponData).id))
	var data: WeaponData = weapons[_debug_weapon_index % weapons.size()] as WeaponData
	_debug_weapon_index += 1
	player.weapon_slots.add_weapon(data)


func _draw() -> void:
	draw_rect(config.get_rect(), config.border_color, false, config.border_width)
