class_name Structure
extends Node2D
## Struktur (Lampenturm): schießt auf das nächste Ziel in Reichweite. Schaden skaliert mit Technik,
## nicht mit Schaden-%; Angriffstempo mit dem Struktur-Angriffstempo-Stat. Höheres Tier = schneller.
## Türme aus Items (Paket 8): Flammenstrahl mit Brand, Frost-Aura, Heil-Aura und Minenleger.

signal mine_requested(structure: Structure, at: Vector2)

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const TOWERS: TowerConfig = preload("res://data/config/tower_config.tres")
const NO_EXCLUDE: Dictionary[int, bool] = {}

var data: StructureData
var tier: int = 1
var player: Player
## Boden-Ebene für die Aura (unter Gegnern und Spieler); ohne sie zeichnet der Turm die Aura selbst.
var ground: Node2D

var _cooldown_left: float = 0.0
var _aura: TowerAura
var _beam_to: Vector2 = Vector2.ZERO
var _beam_left: float = 0.0

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _muzzle: Marker2D = $Muzzle


func setup(p_data: StructureData, p_tier: int, p_player: Player) -> void:
	data = p_data
	tier = p_tier
	player = p_player


func _ready() -> void:
	_sprite.texture = data.texture
	_sprite.offset = Vector2(0.0, -data.texture.get_height() * 0.5)
	_muzzle.position = Vector2(0.0, -data.texture.get_height() * 0.8)
	Juice.spawn_pop(_visual).finished.connect(func() -> void: Juice.idle_bob(_visual), CONNECT_ONE_SHOT)
	if data.kind == StructureData.Kind.FROST or data.kind == StructureData.Kind.HEAL:
		_aura = TowerAura.new()
		_aura.color = data.aura_color
		_aura.radius = get_aura_radius()
		if ground != null:
			ground.add_child(_aura)
			_aura.global_position = global_position
		else:
			add_child(_aura)
	# Heilung und Minen erst nach der ersten Abklingzeit, nicht sofort beim Bauen
	if data.kind == StructureData.Kind.HEAL or data.kind == StructureData.Kind.MINE_LAYER:
		_cooldown_left = get_cooldown()


func _exit_tree() -> void:
	if _aura != null and is_instance_valid(_aura) and _aura.get_parent() != self:
		_aura.queue_free()


func get_cooldown() -> float:
	return data.cooldown(tier, player.stats)


func get_damage() -> int:
	return data.damage(player.stats)


func get_aura_radius() -> float:
	return data.aura(player.stats)


func _physics_process(delta: float) -> void:
	if _beam_left > 0.0:
		_beam_left -= delta
		queue_redraw()
	if player == null or player.is_dead:
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	match data.kind:
		StructureData.Kind.ROOT:
			_cooldown_left = STATUS.root_check_interval
			_root_enemies()
		StructureData.Kind.FROST:
			_cooldown_left = get_cooldown()
			_chill_enemies()
		StructureData.Kind.HEAL:
			_cooldown_left = get_cooldown()
			_heal_player()
		StructureData.Kind.MINE_LAYER:
			_cooldown_left = get_cooldown()
			_lay_mine()
		_:
			var target: Damageable = Hits.nearest_target(get_tree(), _muzzle.global_position, data.range, NO_EXCLUDE)
			if target == null:
				return
			_cooldown_left = get_cooldown()
			if data.kind == StructureData.Kind.FLAME:
				_flame(target)
			else:
				_fire(target)


func _fire(target: Damageable) -> void:
	var pool: ObjectPool = Pools.get_pool(get_tree(), Pools.PLAYER_PROJECTILES)
	if pool == null:
		return
	var spec: ProjectileSpec = ProjectileSpec.new()
	spec.texture = data.projectile_texture
	spec.speed = data.projectile_speed
	spec.max_range = data.range
	spec.info = DamageInfo.create(get_damage(), false, 0.0, self, DamageSource.structure(data.id))
	spec.player = player
	spec.lifesteal = false
	var start: Vector2 = _muzzle.global_position
	(pool.acquire() as Projectile).launch(start, start.direction_to(target.get_hit_position()).angle(), spec)


## Flammenstrahl bis zur vollen Reichweite in Richtung des Ziels: trifft alles nahe der Strahllinie und setzt Brand.
func _flame(target: Damageable) -> void:
	var start: Vector2 = _muzzle.global_position
	var end: Vector2 = start + start.direction_to(target.get_hit_position()) * data.range
	var half_width: float = data.beam_width * 0.5
	var in_beam: Array[Damageable] = []
	for enemy: Damageable in Hits.alive_targets(get_tree(), true):
		var hit_pos: Vector2 = enemy.get_hit_position()
		if Geometry2D.get_closest_point_to_segment(hit_pos, start, end).distance_to(hit_pos) <= half_width:
			in_beam.append(enemy)
	in_beam.sort_custom(func(a: Damageable, b: Damageable) -> bool:
		return start.distance_squared_to(a.get_hit_position()) < start.distance_squared_to(b.get_hit_position()))
	for enemy: Damageable in in_beam.slice(0, data.beam_max_targets):
		var info: DamageInfo = DamageInfo.create(get_damage(), false, 0.0, self, DamageSource.structure(data.id))
		info.burn_damage = data.burn_tick(player.stats)
		info.burn_ticks = data.burn_ticks
		Hits.apply_weapon_hit(enemy, info, player, false)
	_beam_to = to_local(end)
	_beam_left = TOWERS.flame_visible_time
	queue_redraw()


## Frost: verlangsamt alle Gegner in der Aura (SlowStatus; die stärkere Verlangsamung gewinnt).
func _chill_enemies() -> void:
	var radius: float = get_aura_radius()
	_aura.radius = radius
	for target: Damageable in Hits.alive_targets(get_tree()):
		var enemy: Enemy = target as Enemy
		if enemy != null and enemy.global_position.distance_to(global_position) <= radius:
			enemy.apply_slow(1.0 - data.slow_pct / StructureData.PERCENT, data.slow_duration)


## Heilung: nur wenn der Spieler in der Aura steht; grüne Zahl über dem Spieler.
func _heal_player() -> void:
	var radius: float = get_aura_radius()
	_aura.radius = radius
	if player.global_position.distance_to(global_position) > radius:
		return
	var healed: float = player.heal(data.heal(player.stats))
	if healed > 0.0:
		_aura.flash()
		Pools.spawn_text(get_tree(), "+%d" % roundi(healed), TOWERS.heal_number_color, TOWERS.heal_number_font_size,
			player.get_center() + TOWERS.heal_number_offset)


func _lay_mine() -> void:
	var offset: Vector2 = Vector2.from_angle(player.rng.randf() * TAU) * player.rng.randf_range(0.3, 1.0) * data.mine_spread
	mine_requested.emit(self, global_position + offset)


## Ranke: hält alle Gegner im Radius fest (mit Schutzzeit danach, siehe Enemy.root).
func _root_enemies() -> void:
	for target: Damageable in Hits.alive_targets(get_tree()):
		var enemy: Enemy = target as Enemy
		if enemy != null and enemy.global_position.distance_to(global_position) <= data.root_radius:
			enemy.root(data.root_duration)


func _draw() -> void:
	if _beam_left <= 0.0:
		return
	var alpha: float = clampf(_beam_left / TOWERS.flame_visible_time, 0.0, 1.0)
	var from: Vector2 = _muzzle.position
	var side: Vector2 = from.direction_to(_beam_to).orthogonal()
	# Flammenkegel: schmal an der Mündung, am Ende so breit wie der Trefferbereich; heller Kern in der Mitte
	_draw_cone(from, _beam_to, side, data.beam_width * 0.5, Color(TOWERS.flame_color, alpha * 0.75))
	_draw_cone(from, from.lerp(_beam_to, 0.8), side, data.beam_width * 0.2, Color(TOWERS.flame_core_color, alpha))


func _draw_cone(from: Vector2, to: Vector2, side: Vector2, half_width: float, color: Color) -> void:
	var tip: float = half_width * 0.15
	draw_colored_polygon(PackedVector2Array([from + side * tip, to + side * half_width, to - side * half_width, from - side * tip]), color)
