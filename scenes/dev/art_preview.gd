extends Node2D
## Entwickler-Vorschau: zeigt alle Sprites mit ihren Code-Animationen (Phase 1).
## Labels sind reine Dateinamen und laufen deshalb nicht über die Übersetzungstabelle.

const FLOOR_TEXTURE: Texture2D = preload("res://art/world/floor_tile.svg")
const FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const HIT_FLASH: Shader = preload("res://art/shaders/hit_flash.gdshader")
const OUTLINE: Shader = preload("res://art/shaders/outline.gdshader")

const BULBRO: Texture2D = preload("res://art/player/bulbro.svg")
const SCHATTENLING: Texture2D = preload("res://art/enemies/schattenling.svg")
const MOTTE: Texture2D = preload("res://art/enemies/motte.svg")
const RUSSSPUCKER: Texture2D = preload("res://art/enemies/russspucker.svg")
const SPARK: Texture2D = preload("res://art/pickups/spark.svg")
const BATTERY: Texture2D = preload("res://art/pickups/battery.svg")
const CRATE: Texture2D = preload("res://art/pickups/crate.svg")
const CRYSTAL: Texture2D = preload("res://art/world/crystal.svg")
const SPAWN_MARKER: Texture2D = preload("res://art/fx/spawn_marker.svg")
const WEAPONS: Array[Texture2D] = [
	preload("res://art/weapons/funkenpistole.svg"),
	preload("res://art/weapons/glasscherbe.svg"),
	preload("res://art/weapons/ast.svg"),
	preload("res://art/weapons/funkenfaust.svg"),
]
const WEAPON_NAMES: PackedStringArray = ["funkenpistole", "glasscherbe", "ast", "funkenfaust"]

const FLOOR_SIZE: Vector2 = Vector2(2400, 1400)
const COLUMN_GAP: float = 220.0
const ROW_Y: Array[float] = [-280.0, 40.0, 340.0]
const LABEL_OFFSET: float = 24.0
const LABEL_SIZE: int = 22
const LABEL_COLOR: Color = Color("#E8E4F0")
const WALK_AMPLITUDE: float = 90.0
const WALK_FREQUENCY: float = 0.8
const ORBIT_RADIUS: float = 55.0
const ORBIT_SPEED: float = 1.2
const FLASH_INTERVAL: float = 1.2
const DEATH_LOOP_PAUSE: float = 0.6
const SPAWN_MARKER_TIME: float = 1.0
const SPARK_SPIN_SPEED: float = 1.5

var _time: float = 0.0
var _walker: Sprite2D
var _walker_origin: Vector2
var _orbit_center: Sprite2D
var _orbit_weapons: Array[Sprite2D] = []
var _spark: Sprite2D
var _flash_targets: Array[Sprite2D] = []


func _ready() -> void:
	_build_floor()
	var cam: Camera2D = Camera2D.new()
	add_child(cam)

	# Reihe 1: Spieler und Gegner
	_walker = _add_sprite(BULBRO, _col(0, 6), ROW_Y[0], "bulbro (laufen)", true)
	_walker_origin = _walker.position
	_add_sprite(BULBRO, _col(1, 6), ROW_Y[0], "bulbro (idle)", true)
	_add_sprite(SCHATTENLING, _col(2, 6), ROW_Y[0], "schattenling", true)
	var buffed: Sprite2D = _add_sprite(SCHATTENLING, _col(3, 6), ROW_Y[0], "schattenling (buff)", false)
	buffed.material = _shader_material(OUTLINE)
	_flash_targets.append(buffed)
	_add_sprite(MOTTE, _col(4, 6), ROW_Y[0], "motte", true)
	var spitter: Sprite2D = _add_sprite(RUSSSPUCKER, _col(5, 6), ROW_Y[0], "russspucker (tod/spawn)", true)

	# Reihe 2: Pickups, neutrale Objekte, Spawn-Marker
	_spark = _add_sprite(SPARK, _col(0, 5), ROW_Y[1], "spark", false)
	_add_sprite(BATTERY, _col(1, 5), ROW_Y[1], "battery", false)
	_add_sprite(CRATE, _col(2, 5), ROW_Y[1], "crate", false)
	_add_sprite(CRYSTAL, _col(3, 5), ROW_Y[1], "crystal", false)
	var marker: Sprite2D = _add_sprite(SPAWN_MARKER, _col(4, 5), ROW_Y[1], "spawn_marker", false)
	marker.offset = Vector2.ZERO
	Juice.marker_pulse(marker)

	# Reihe 3: Waffen einzeln und im Orbit um Bulbro
	for i in WEAPONS.size():
		_add_sprite(WEAPONS[i], _col(i, 5), ROW_Y[2], WEAPON_NAMES[i], false)
	_orbit_center = _add_sprite(BULBRO, _col(4, 5), ROW_Y[2], "waffen-orbit", true)
	for tex: Texture2D in WEAPONS:
		var w: Sprite2D = Sprite2D.new()
		w.texture = tex
		add_child(w)
		_orbit_weapons.append(w)

	var flash_timer: Timer = Timer.new()
	flash_timer.wait_time = FLASH_INTERVAL
	flash_timer.autostart = true
	flash_timer.timeout.connect(_flash_all)
	add_child(flash_timer)

	_death_loop(spitter)


func _process(delta: float) -> void:
	_time += delta
	var phase: float = _time * TAU * WALK_FREQUENCY * 0.5
	_walker.position.x = _walker_origin.x + sin(phase) * WALK_AMPLITUDE
	var velocity: Vector2 = Vector2(cos(phase) * WALK_AMPLITUDE * TAU * WALK_FREQUENCY * 0.5, 0.0)
	Juice.walk_tilt(_walker, velocity)

	_spark.rotation = sin(_time * SPARK_SPIN_SPEED) * 0.3

	var center: Vector2 = _orbit_center.position + Vector2(0.0, -_orbit_center.texture.get_height() * 0.5)
	for i in _orbit_weapons.size():
		var angle: float = _time * ORBIT_SPEED + TAU * i / _orbit_weapons.size()
		_orbit_weapons[i].position = center + Vector2.from_angle(angle) * ORBIT_RADIUS


func _death_loop(sprite: Sprite2D) -> void:
	while is_inside_tree():
		await get_tree().create_timer(DEATH_LOOP_PAUSE * 2.0).timeout
		await Juice.squash_pop(sprite).finished
		var marker: Sprite2D = Sprite2D.new()
		marker.texture = SPAWN_MARKER
		marker.position = sprite.position + Vector2(0.0, -sprite.texture.get_height() * 0.5)
		add_child(marker)
		Juice.marker_pulse(marker)
		await get_tree().create_timer(SPAWN_MARKER_TIME).timeout
		marker.queue_free()
		await Juice.spawn_pop(sprite).finished
		Juice.idle_bob(sprite)


func _flash_all() -> void:
	for target: Sprite2D in _flash_targets:
		Juice.hit_flash(target)


func _add_sprite(tex: Texture2D, x: float, y: float, label_text: String, animate: bool) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.position = Vector2(x, y)
	sprite.offset = Vector2(0.0, -tex.get_height() * 0.5)
	if animate:
		sprite.material = _shader_material(HIT_FLASH)
		_flash_targets.append(sprite)
		Juice.idle_bob(sprite)
	add_child(sprite)

	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", LABEL_SIZE)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(COLUMN_GAP, LABEL_SIZE * 1.5)
	label.position = Vector2(x - COLUMN_GAP * 0.5, y + LABEL_OFFSET)
	add_child(label)
	return sprite


func _shader_material(shader: Shader) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat


func _build_floor() -> void:
	var floor_sprite: Sprite2D = Sprite2D.new()
	floor_sprite.texture = FLOOR_TEXTURE
	floor_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_sprite.region_enabled = true
	floor_sprite.region_rect = Rect2(Vector2.ZERO, FLOOR_SIZE)
	add_child(floor_sprite)


func _col(index: int, count: int) -> float:
	return (index - (count - 1) * 0.5) * COLUMN_GAP
