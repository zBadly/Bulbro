class_name FireballFx
extends Node2D
## Feuerball (Kronleuchter): fliegt vom Spieler zum Zielort, zieht eine Funkenspur hinter sich her
## und ruft beim Ankommen `on_arrive` auf (dort explodiert er). Rein grafisch, der Schaden kommt aus der Aktion.

const TEXTURE: Texture2D = preload("res://art/fx/fireball.svg")
const TRAIL_TEXTURE: Texture2D = preload("res://art/fx/particle_dot.svg")
const TRAIL_AMOUNT: int = 16
const TRAIL_LIFETIME: float = 0.3
const TRAIL_SCALE: Vector2 = Vector2(0.5, 1.0)
const TRAIL_START: Color = Color("#FFD43B")
const TRAIL_END: Color = Color("#FF8C4200")
const TRAIL_SPREAD: float = 25.0
const TRAIL_SPEED: float = 60.0
## Leicht pulsierende Größe während des Flugs.
const PULSE_SPEED: float = 30.0
const PULSE_AMOUNT: float = 0.08

var _target: Vector2
var _speed: float = 0.0
var _on_arrive: Callable
var _sprite: Sprite2D
var _trail: GPUParticles2D
var _flying: bool = false


func launch(from: Vector2, to: Vector2, speed: float, on_arrive: Callable) -> void:
	global_position = from
	_target = to
	_speed = speed
	_on_arrive = on_arrive
	_trail = _make_trail()
	add_child(_trail)
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.rotation = from.angle_to_point(to)
	add_child(_sprite)
	_trail.emitting = true
	_flying = true


func _process(delta: float) -> void:
	if not _flying:
		return
	var step: float = _speed * delta
	if global_position.distance_to(_target) <= step:
		global_position = _target
		_arrive()
		return
	global_position = global_position.move_toward(_target, step)
	_sprite.scale = Vector2.ONE * (1.0 + PULSE_AMOUNT * sin(Time.get_ticks_msec() * 0.001 * PULSE_SPEED))


func _arrive() -> void:
	_flying = false
	_sprite.hide()
	_trail.emitting = false
	if _on_arrive.is_valid():
		_on_arrive.call()
	get_tree().create_timer(TRAIL_LIFETIME).timeout.connect(queue_free)


func _make_trail() -> GPUParticles2D:
	var trail: GPUParticles2D = GPUParticles2D.new()
	trail.amount = TRAIL_AMOUNT
	trail.lifetime = TRAIL_LIFETIME
	trail.local_coords = false
	trail.emitting = false
	trail.texture = TRAIL_TEXTURE
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.spread = TRAIL_SPREAD
	material.direction = Vector3(-1.0, 0.0, 0.0)
	material.initial_velocity_max = TRAIL_SPEED
	material.scale_min = TRAIL_SCALE.x
	material.scale_max = TRAIL_SCALE.y
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, TRAIL_START)
	ramp.set_color(1, TRAIL_END)
	var ramp_texture: GradientTexture1D = GradientTexture1D.new()
	ramp_texture.gradient = ramp
	material.color_ramp = ramp_texture
	trail.process_material = material
	return trail
