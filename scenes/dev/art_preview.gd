extends Node2D
## Entwickler-Vorschau: zeigt alle Sprites mit ihren Code-Animationen (Phase 1), dazu die Charaktere 13-22
## mit Porträts sowie Status- und Zaubereffekte (Paket 4).
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
const NEW_CHARACTERS: PackedStringArray = ["irrlicht", "zuendkerze", "kronleuchter", "schwarzlicht", "gewaechshauslampe",
	"smartbulb", "drohnenleuchte", "stroboskop", "vampirbirne", "spiegelkugel"]
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const SCHATTENLING_DATA: EnemyData = preload("res://data/enemies/schattenling.tres")
const ALLY_SCENE: PackedScene = preload("res://scenes/allies/ally.tscn")
const MIRROR_SHADER: Shader = preload("res://art/shaders/mirror_sheen.gdshader")
const DUMMY: Texture2D = preload("res://art/enemies/training_dummy.svg")
const LICHTRANKE: Texture2D = preload("res://art/world/lichtranke.svg")
const DROHNE: Texture2D = preload("res://art/world/drohne.svg")
const LAMPENTURM: Texture2D = preload("res://art/world/lampenturm.svg")
const CURSE_PREVIEW_STACKS: Array[int] = [1, 2, 3]
const STATUS_COLUMNS: int = 10
const SPELL_INTERVAL: float = 1.1
const STROBE_INTERVAL: float = 3.0
const FIREBALL_SPEED: float = 1100.0
const FIREBALL_RADIUS: float = 70.0
const NOVA_RADIUS: float = 110.0
const ZOOM: float = 0.56

const FLOOR_SIZE: Vector2 = Vector2(3600, 2200)
const COLUMN_GAP: float = 220.0
const ROW_Y: Array[float] = [-820.0, -580.0, -340.0, -60.0, 200.0, 500.0, 800.0]
const LABEL_OFFSET: float = 24.0
const LABEL_SIZE: int = 30
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
var _swing: Sprite2D
var _swing_walker: Sprite2D
var _swing_origin: Vector2
var _strobe: Sprite2D
var _burn_flames: Array[Sprite2D] = []
var _drone: Sprite2D
var _drone_center: Vector2
var _dummies: Array[Sprite2D] = []
var _spell_index: int = 0
var _caster: Sprite2D


func _ready() -> void:
	_build_floor()
	var cam: Camera2D = Camera2D.new()
	cam.zoom = Vector2.ONE * ZOOM
	add_child(cam)
	var fx_layer: Node2D = Node2D.new()
	fx_layer.add_to_group(Fx.FX_GROUP)
	fx_layer.z_index = 20
	add_child(fx_layer)
	var particles: ParticleFx = ParticleFx.new()
	particles.z_index = 15
	add_child(particles)

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
	_build_characters()
	_build_statuses()
	_build_spells()


func _process(delta: float) -> void:
	_time += delta
	var phase: float = _time * TAU * WALK_FREQUENCY * 0.5
	_walker.position.x = _walker_origin.x + sin(phase) * WALK_AMPLITUDE
	var velocity: Vector2 = Vector2(cos(phase) * WALK_AMPLITUDE * TAU * WALK_FREQUENCY * 0.5, 0.0)
	Juice.walk_tilt(_walker, velocity)

	_spark.rotation = sin(_time * SPARK_SPIN_SPEED) * 0.3

	if _swing != null:
		var swing_velocity: Vector2 = Vector2(cos(phase * 1.3) * WALK_AMPLITUDE * 3.0, 0.0)
		_swing_walker.position.x = _swing_origin.x + sin(phase * 1.3) * WALK_AMPLITUDE * 0.5
		Juice.walk_tilt(_swing_walker, swing_velocity)
		Juice.swing(_swing, swing_velocity, delta)
	for flames: Sprite2D in _burn_flames:
		var wave_t: float = _time * STATUS.burn_flicker_speed
		var base: Vector2 = flames.get_meta(&"base_scale")
		flames.scale = base * Vector2(1.0 - STATUS.burn_flicker_amount * 0.5 * sin(wave_t), 1.0 + STATUS.burn_flicker_amount * sin(wave_t))
	if _drone != null:
		_drone.position = _drone_center + Vector2.from_angle(_time * deg_to_rad(STATUS.drone_orbit_speed_deg)) * STATUS.drone_orbit_radius

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


# --- Paket 4: Charaktere 13-22, Status- und Zaubereffekte ---

func _build_characters() -> void:
	var count: int = NEW_CHARACTERS.size()
	for i in count:
		var data: CharacterData = load("res://data/characters/%s.tres" % NEW_CHARACTERS[i])
		var sprite: Sprite2D = _add_sprite(data.texture, _col(i, count), ROW_Y[3], NEW_CHARACTERS[i], true)
		if data.idle_style == CharacterData.IdleStyle.HOVER_FLICKER:
			Juice.hover(sprite)
			Juice.flicker(sprite)
		if data.swing_texture != null:
			_swing_walker = sprite
			_swing_origin = sprite.position
			_swing = Sprite2D.new()
			_swing.texture = data.swing_texture
			_swing.centered = false
			_swing.material = sprite.material
			var size: Vector2 = data.texture.get_size()
			_swing.position = Vector2(data.swing_pivot.x - size.x * 0.5, data.swing_pivot.y - size.y)
			_swing.offset = -data.swing_pivot
			sprite.add_child(_swing)
		if data.id == &"stroboskop":
			_strobe = sprite
		_add_sprite(data.get_portrait(), _col(i, count), ROW_Y[4], "", false)


func _build_statuses() -> void:
	var tex: Texture2D = SCHATTENLING
	for i in CURSE_PREVIEW_STACKS.size():
		var cursed: Sprite2D = _add_sprite(tex, _col(i, STATUS_COLUMNS), ROW_Y[5], "fluch x%d" % CURSE_PREVIEW_STACKS[i], true)
		_tint(cursed, STATUS.curse_tint)
		var marker: CurseMarker = CurseMarker.new()
		marker.position = Vector2(0.0, -tex.get_height() - STATUS.curse_marker_gap)
		cursed.add_child(marker)
		marker.show_stacks(CURSE_PREVIEW_STACKS[i])

	var ghost: Ally = ALLY_SCENE.instantiate()
	add_child(ghost)
	ghost.summon(SCHATTENLING_DATA, Vector2(_col(3, STATUS_COLUMNS), ROW_Y[5]), 0, INF, Rect2())
	_add_label("schattengeist", _col(3, STATUS_COLUMNS), ROW_Y[5])

	var frozen: Sprite2D = _add_sprite(tex, _col(4, STATUS_COLUMNS), ROW_Y[5], "eingefroren", true)
	_tint(frozen, STATUS.frost_tint)
	_add_overlay(frozen, Enemy.ICE_TEXTURE, true)
	var slowed: Sprite2D = _add_sprite(tex, _col(5, STATUS_COLUMNS), ROW_Y[5], "verlangsamt", true)
	_tint(slowed, STATUS.frost_tint)
	_frost_loop(slowed)
	var rooted: Sprite2D = _add_sprite(tex, _col(6, STATUS_COLUMNS), ROW_Y[5], "festgehalten", true)
	_add_overlay(rooted, Enemy.ROOT_TEXTURE, true)
	var burning: Sprite2D = _add_sprite(tex, _col(7, STATUS_COLUMNS), ROW_Y[5], "brennt", true)
	_tint(burning, COMBAT.burn_tint)
	_burn_flames.append(_add_overlay(burning, Enemy.BURN_TEXTURE, false))

	var mirror: Sprite2D = _add_sprite(load("res://art/characters/spiegelkugel.svg"), _col(8, STATUS_COLUMNS), ROW_Y[5], "spiegelbild", false)
	mirror.modulate = STATUS.mirror_tint
	var sheen: ShaderMaterial = _shader_material(MIRROR_SHADER)
	sheen.set_shader_parameter(&"sheen_period", STATUS.mirror_sheen_period)
	sheen.set_shader_parameter(&"sheen_strength", STATUS.mirror_sheen_strength)
	mirror.material = sheen
	Juice.idle_bob(mirror)
	_add_sprite(LICHTRANKE, _col(9, STATUS_COLUMNS), ROW_Y[5], "lichtranke", true)


## Eis, Ranken oder Flammen wie in Enemy.setup: Größe nach dem Körperdurchmesser.
func _add_overlay(target: Sprite2D, tex: Texture2D, at_feet: bool) -> Sprite2D:
	var body_width: float = SCHATTENLING_DATA.collision_radius * 2.0 * STATUS.status_overlay_scale
	var overlay: Sprite2D = Sprite2D.new()
	overlay.texture = tex
	if at_feet:
		overlay.scale = Vector2.ONE * body_width / tex.get_width()
		overlay.position = Vector2(0.0, -tex.get_height() * 0.35 * overlay.scale.y)
	else:
		overlay.scale = Vector2.ONE * body_width * 0.8 / tex.get_width()
		overlay.position = Vector2(0.0, -target.texture.get_height() * 0.5 * 0.9)
	overlay.set_meta(&"base_scale", overlay.scale)
	target.add_child(overlay)
	return overlay


func _tint(sprite: Sprite2D, color: Color) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter(Enemy.TINT_PARAM, color)


func _frost_loop(target: Sprite2D) -> void:
	while is_inside_tree():
		Fx.particles(get_tree(), ParticleFx.Kind.FROST, target.global_position + Vector2(0.0, -target.texture.get_height() * 0.5))
		await get_tree().create_timer(STATUS.frost_particle_interval).timeout


func _build_spells() -> void:
	_caster = _add_sprite(load("res://art/characters/kronleuchter.svg"), _col(0, STATUS_COLUMNS), ROW_Y[6], "zauber", true)
	for i in 6:
		_dummies.append(_add_sprite(DUMMY, _col(2 + i, STATUS_COLUMNS), ROW_Y[6], "", true))
	_add_label("feuerball / frostnova / kettenblitz", _col(4, STATUS_COLUMNS) + COLUMN_GAP * 0.5, ROW_Y[6])
	var tower: Sprite2D = _add_sprite(LAMPENTURM, _col(9, STATUS_COLUMNS), ROW_Y[6], "licht-drohne", false)
	_drone_center = tower.position + Vector2(0.0, -tower.texture.get_height() * 0.5)
	_drone = Sprite2D.new()
	_drone.texture = DROHNE
	add_child(_drone)
	Juice.idle_bob(_drone)

	var spell_timer: Timer = Timer.new()
	spell_timer.wait_time = SPELL_INTERVAL
	spell_timer.autostart = true
	spell_timer.timeout.connect(_cast_next_spell)
	add_child(spell_timer)
	var strobe_timer: Timer = Timer.new()
	strobe_timer.wait_time = STROBE_INTERVAL
	strobe_timer.autostart = true
	strobe_timer.timeout.connect(_strobe_flash)
	add_child(strobe_timer)
	_cast_next_spell()


func _sprite_center(sprite: Sprite2D) -> Vector2:
	return sprite.position + Vector2(0.0, -sprite.texture.get_height() * 0.5)


func _cast_next_spell() -> void:
	match _spell_index % 3:
		0:
			var target: Vector2 = _sprite_center(_dummies[0])
			Fx.fireball(get_tree(), _sprite_center(_caster), target, FIREBALL_SPEED, func() -> void:
				Fx.explosion(get_tree(), target, FIREBALL_RADIUS)
				Fx.particles(get_tree(), ParticleFx.Kind.EXPLOSION, target))
		1:
			Fx.frost_nova(get_tree(), _sprite_center(_dummies[2]), NOVA_RADIUS)
		2:
			for i in range(3, _dummies.size()):
				Fx.zap(get_tree(), _sprite_center(_dummies[i]))
				if i > 3:
					Fx.lightning(get_tree(), _sprite_center(_dummies[i - 1]), _sprite_center(_dummies[i]))
	_spell_index += 1


func _strobe_flash() -> void:
	Juice.effect_flash(_strobe)
	Fx.screen_flash(get_tree())


func _add_label(text: String, x: float, y: float) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", LABEL_SIZE)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(COLUMN_GAP * 2.0, LABEL_SIZE * 1.5)
	label.position = Vector2(x - COLUMN_GAP, y + LABEL_OFFSET)
	add_child(label)
