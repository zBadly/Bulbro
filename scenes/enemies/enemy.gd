class_name Enemy
extends Damageable
## Gepoolter Gegner. Werte kommen aus EnemyData, die Bewegung aus einer Verhaltens-Komponente.
## Kontaktschaden per Abstandsprüfung (günstiger als Area2D bei 100 Gegnern).

signal died(enemy: Enemy)
## Bitte an den WaveManager, Gegner zu erzeugen (Beschwörung, Brutsack).
signal summon_requested(data: EnemyData, count: int, position: Vector2)

const OUTLINE_SHADER: Shader = preload("res://art/shaders/outline.gdshader")
const BUFF_OUTLINE_PARAM: StringName = &"outline_color"
const BUFF_COLOR: Color = Color("#E74C3C")
## Status-Farbton im Shader (Alpha = Stärke); NO_TINT = kein Status.
const TINT_PARAM: StringName = &"tint_color"
const NO_TINT: Color = Color(1.0, 1.0, 1.0, 0.0)

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const WAVES: WaveConfig = preload("res://data/config/wave_config.tres")
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
## Gruppe der gerade verfluchten Gegner (Zähler für die Schwarzlicht-Freischaltung).
const CURSED_GROUP: StringName = &"cursed_enemies"
const BURN_TEXTURE: Texture2D = preload("res://art/fx/burn_flames.svg")
const ICE_TEXTURE: Texture2D = preload("res://art/fx/ice_crystals.svg")
const ROOT_TEXTURE: Texture2D = preload("res://art/fx/root_vines.svg")

var data: EnemyData
var pool: ObjectPool
var player: Player
var arena_bounds: Rect2 = Rect2()
var rng: RandomNumberGenerator
var wave: int = 1
var max_hp: float = 0.0
var hp: float = 0.0
var damage: float = 0.0
var speed: float = 0.0
var projectile_damage: float = 0.0
## Multiplikator auf alle Tempos (Gegnertempo-Stat, Verstärker-Buff).
var speed_factor: float = 1.0
var is_buffed: bool = false
## Zusätzlicher HP-Faktor für diesen Spawn (z. B. Elites auf Welle 11/12, doppelter Boss).
var hp_multiplier: float = 1.0
var curse: CurseStatus = CurseStatus.new()
var slow: SlowStatus = SlowStatus.new()

var _alive: bool = false
var _behavior: EnemyBehavior
var _contact_distance: float = 0.0
var _last_hit: DamageInfo
var _burn_damage: float = 0.0
var _burn_ticks_left: int = 0
var _burn_timer: float = 0.0
var _burn_source: Player
## Herkunft von Brand und Fluch (Run-Statistik).
var _burn_origin: StringName = &""
var _curse_origin: StringName = &""
var _flash_material: ShaderMaterial
var _buff_material: ShaderMaterial
var _root_immune_left: float = 0.0
var _curse_marker: CurseMarker
## Flammen auf brennenden Gegnern und Eis/Ranken an den Füßen (eingefroren/festgehalten).
var _burn_fx: Sprite2D
var _hold_fx: Sprite2D
var _burn_fx_scale: Vector2 = Vector2.ONE
var _rooted: bool = false
var _frost_particle_left: float = 0.0
## HP-Leiste unter normalen Gegnern (null bei Elites und Bossen).
var _hp_bar: EnemyHpBar

@onready var visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _shape: CollisionShape2D = $CollisionShape


## Einmalig nach dem Erzeugen im Pool: legt Grafik, Kollision und Verhalten fest.
func setup(p_data: EnemyData) -> void:
	data = p_data
	_sprite.texture = data.texture
	var half_height: float = data.texture.get_height() * 0.5
	_sprite.offset = Vector2(0.0, -half_height)
	hit_height = half_height
	_shape.position = Vector2(0.0, -half_height)
	(_shape.shape as CircleShape2D).radius = data.collision_radius
	_flash_material = _sprite.material as ShaderMaterial
	_buff_material = ShaderMaterial.new()
	_buff_material.shader = OUTLINE_SHADER
	_buff_material.set_shader_parameter(BUFF_OUTLINE_PARAM, BUFF_COLOR)
	_curse_marker = CurseMarker.new()
	_curse_marker.position = Vector2(0.0, -data.texture.get_height() - STATUS.curse_marker_gap)
	visual.add_child(_curse_marker)
	var body_width: float = data.collision_radius * 2.0 * STATUS.status_overlay_scale
	_hold_fx = _make_overlay(visual, Vector2(0.0, -ICE_TEXTURE.get_height() * 0.35 * body_width / ICE_TEXTURE.get_width()), body_width / ICE_TEXTURE.get_width())
	_burn_fx = _make_overlay(visual, Vector2(0.0, -half_height * 0.9), body_width * 0.8 / BURN_TEXTURE.get_width())
	_burn_fx.texture = BURN_TEXTURE
	_burn_fx_scale = _burn_fx.scale
	if not data.is_elite and not data.is_boss:
		_hp_bar = EnemyHpBar.new()
		_hp_bar.setup(data.collision_radius)
		add_child(_hp_bar)
	_behavior = data.behavior.create_behavior()
	_behavior.enemy = self
	add_child(_behavior)


func _make_overlay(parent: Node2D, at: Vector2, factor: float) -> Sprite2D:
	var overlay: Sprite2D = Sprite2D.new()
	overlay.position = at
	overlay.scale = Vector2.ONE * factor
	overlay.visible = false
	parent.add_child(overlay)
	return overlay


## Beim Holen aus dem Pool: setzt Werte für die Welle und spielt das Pop-in.
func activate(p_wave: int, spawn_position: Vector2, p_player: Player, bounds: Rect2, p_rng: RandomNumberGenerator) -> void:
	wave = p_wave
	player = p_player
	arena_bounds = bounds
	rng = p_rng
	global_position = spawn_position
	var difficulty: DifficultyData = GameState.difficulty
	var hp_factor: float = 1.0 + (difficulty.enemy_hp_pct / CombatMath.PERCENT if difficulty != null else 0.0)
	var damage_factor: float = 1.0 + (difficulty.enemy_damage_pct / CombatMath.PERCENT if difficulty != null else 0.0)
	hp_factor *= GameState.endless_factor(WAVES.endless_hp_growth)
	damage_factor *= GameState.endless_factor(WAVES.endless_damage_growth)
	max_hp = data.hp_for_wave(wave) * hp_factor * hp_multiplier * GameState.assist_hp
	hp = max_hp
	damage = data.damage_for_wave(wave) * damage_factor * GameState.assist_damage
	projectile_damage = data.projectile_damage_for_wave(wave) * damage_factor * GameState.assist_damage
	speed_factor = maxf(0.0, 1.0 + p_player.stats.get_stat(Stats.ENEMY_SPEED_PCT) / CombatMath.PERCENT) * GameState.assist_speed * GameState.endless_factor(WAVES.endless_speed_growth, WAVES.endless_speed_max)
	speed = rng.randf_range(data.speed_min, data.speed_max) * speed_factor
	is_buffed = false
	_sprite.material = _flash_material
	knockback_velocity = Vector2.ZERO
	_last_hit = null
	_burn_ticks_left = 0
	_clear_statuses()
	_contact_distance = data.collision_radius + player.config.collision_radius
	_sprite.flip_h = false
	visual.rotation = 0.0
	_alive = true
	_update_hp_bar()
	_behavior.reset()
	Juice.spawn_pop(visual).finished.connect(_on_spawned, CONNECT_ONE_SHOT)
	if data.is_boss or data.is_elite:
		Events.boss_spawned.emit(self)


func is_alive() -> bool:
	return _alive


func direction_to_player() -> Vector2:
	return global_position.direction_to(player.global_position)


func distance_to_player() -> float:
	return global_position.distance_to(player.global_position)


func take_damage(info: DamageInfo) -> void:
	if not _alive:
		return
	var amount: int = info.amount
	if GameState.admin.damage_factor != 1.0:
		amount = roundi(amount * GameState.admin.damage_factor)
	if curse.is_active():
		amount = maxi(CombatMath.MIN_DAMAGE, roundi(amount * curse.damage_taken_factor()))
	# Gezählt wird nur der Schaden, den der Gegner wirklich verliert (kein Overkill).
	Events.enemy_damaged.emit(info.origin, mini(amount, ceili(hp)))
	hp -= amount
	_last_hit = info
	_update_hp_bar()
	Juice.hit_flash(_sprite)
	AudioManager.play(&"hit_crit" if info.is_crit else &"hit")
	Fx.particles(get_tree(), ParticleFx.Kind.HIT, get_hit_position(), info.knockback_dir)
	if info.is_crit:
		Fx.hit_stop(get_tree())
	Pools.spawn_damage_number(get_tree(), amount, info.is_crit, get_hit_position())
	apply_knockback(info.knockback_dir * info.knockback * COMBAT.knockback_to_speed * (1.0 - data.knockback_resistance))
	if hp <= 0.0:
		die()


## Tod durch Schaden: Drops auslösen und Tod-Animation abspielen.
func die() -> void:
	if not _alive:
		return
	_alive = false
	if _hp_bar != null:
		_hp_bar.hide()
	if is_burning():
		Events.burning_enemy_killed.emit(global_position)
	Events.enemy_killed.emit(data, global_position, _last_hit)
	_clear_statuses()
	if data.death_spawn != null and data.death_spawn_count > 0:
		summon_requested.emit(data.death_spawn, data.death_spawn_count, global_position)
	died.emit(self)
	Juice.squash_pop(visual).finished.connect(_release, CONNECT_ONE_SHOT)


## Verschwinden ohne Drop: sofort (Gegnerlimit) oder mit Pop-Animation (Wellenende).
func despawn(animated: bool = false) -> void:
	if not _alive:
		return
	_alive = false
	if _hp_bar != null:
		_hp_bar.hide()
	_clear_statuses()
	died.emit(self)
	if animated:
		Juice.squash_pop(visual).finished.connect(_release, CONNECT_ONE_SHOT)
	else:
		_release()


func fire_projectile(direction: Vector2, projectile_speed: float, projectile_range: float, texture: Texture2D) -> void:
	fire_projectile_from(get_hit_position(), direction, projectile_speed, projectile_range, texture)


func fire_projectile_from(origin: Vector2, direction: Vector2, projectile_speed: float, projectile_range: float, texture: Texture2D) -> void:
	var projectile_pool: ObjectPool = Pools.get_pool(get_tree(), Pools.ENEMY_PROJECTILES)
	if projectile_pool == null:
		return
	var projectile: EnemyProjectile = projectile_pool.acquire() as EnemyProjectile
	projectile.launch(origin, direction, projectile_speed, projectile_range, projectile_damage, texture)


func heal(amount: float) -> void:
	if _alive:
		hp = minf(max_hp, hp + amount)
		_update_hp_bar()


## Verstärker-Buff: mehr HP, Schaden und Tempo, rote Kontur. Wirkt nur einmal.
func apply_buff(hp_mult: float, damage_mult: float, speed_mult: float) -> void:
	if not _alive or is_buffed:
		return
	is_buffed = true
	max_hp *= hp_mult
	hp *= hp_mult
	damage *= damage_mult
	projectile_damage *= damage_mult
	speed *= speed_mult
	speed_factor *= speed_mult
	_sprite.material = _buff_material


func _update_hp_bar() -> void:
	if _hp_bar != null:
		_hp_bar.set_ratio(hp / max_hp if max_hp > 0.0 else 0.0)


## Nächster lebender Verbündeter (für Heiler).
func nearest_ally() -> Enemy:
	var best: Enemy = null
	var best_dist: float = INF
	for target: Damageable in Hits.alive_targets(get_tree()):
		var other: Enemy = target as Enemy
		if other == null or other == self:
			continue
		var dist: float = other.global_position.distance_squared_to(global_position)
		if dist < best_dist:
			best = other
			best_dist = dist
	return best


## Überspannung: Brandschaden über Zeit. Ein stärkerer oder längerer Brand ersetzt den alten.
func apply_burn(damage_per_tick: float, ticks: int, source: Player, origin: StringName = &"") -> void:
	if not _alive or ticks <= 0:
		return
	_burn_damage = maxf(_burn_damage if _burn_ticks_left > 0 else 0.0, damage_per_tick)
	_burn_ticks_left = maxi(_burn_ticks_left, ticks)
	_burn_source = source
	_burn_origin = origin
	_update_tint()


func is_burning() -> bool:
	return _burn_ticks_left > 0


func _update_burn(delta: float) -> void:
	if _burn_ticks_left <= 0:
		return
	var speed_pct: float = _burn_source.stats.get_stat(Stats.BURN_SPEED_PCT) if is_instance_valid(_burn_source) else 0.0
	_burn_timer += delta * CombatMath.burn_speed_factor(speed_pct)
	if _burn_timer < COMBAT.burn_interval:
		return
	_burn_timer -= COMBAT.burn_interval
	_burn_ticks_left -= 1
	if _burn_ticks_left <= 0:
		_update_tint()
	_spread_burn()
	var info: DamageInfo = DamageInfo.create(maxi(CombatMath.MIN_DAMAGE, roundi(_burn_damage)), false, 0.0, null, _burn_origin)
	info.is_burn = true
	take_damage(info)


## Brandausbreitung: so viele nahe, nicht brennende Gegner wie der Stat burn_spread angibt.
func _spread_burn() -> void:
	if not is_instance_valid(_burn_source):
		return
	var spread: int = roundi(_burn_source.stats.get_stat(Stats.BURN_SPREAD))
	if spread <= 0:
		return
	for target: Damageable in Hits.alive_targets(get_tree()):
		if spread <= 0:
			break
		var other: Enemy = target as Enemy
		if other == null or other == self or other.is_burning():
			continue
		if other.global_position.distance_to(global_position) <= COMBAT.burn_spread_radius:
			other.apply_burn(_burn_damage, _burn_ticks_left + 1, _burn_source, _burn_origin)
			spread -= 1


# --- Status: Fluch, Verlangsamen, Einfrieren, Festhalten ---

## Fluch (Schwarzlicht): +1 Stapel, Dauer neu, erhöhter erlittener Schaden.
func apply_curse(dps: float, bonus_pct: float, duration: float, max_stacks: int, origin: StringName = &"") -> void:
	if not _alive:
		return
	_curse_origin = origin
	curse.apply(dps, bonus_pct, duration, max_stacks, STATUS.curse_tick_interval)
	if not is_in_group(CURSED_GROUP):
		add_to_group(CURSED_GROUP)
		var run: RunStats = GameState.run_stats
		run.max_cursed = maxi(run.max_cursed, get_tree().get_node_count_in_group(CURSED_GROUP))
	_curse_marker.show_stacks(curse.stacks)
	_update_tint()


func is_cursed() -> bool:
	return curse.is_active()


## Tempo x factor für `duration` Sekunden (Elites/Bosse kürzer). Faktor 0 = eingefroren.
func apply_slow(factor: float, duration: float) -> void:
	if not _alive:
		return
	if data.is_boss or data.is_elite:
		duration *= STATUS.boss_status_factor
	var was_stopped: bool = slow.is_stopped()
	if not slow.is_active():
		_frost_particle_left = randf() * STATUS.frost_particle_interval
	slow.apply(factor, duration)
	if slow.is_stopped() and not was_stopped and not _rooted:
		Fx.particles(get_tree(), ParticleFx.Kind.ICE_POP, get_hit_position())
		_pop_overlay(_hold_fx)
	_update_tint()


func freeze(duration: float) -> void:
	apply_slow(0.0, duration)


## Festhalten (Ranken): wie Einfrieren, danach kurz geschützt, damit niemand dauerhaft gefangen bleibt.
func root(duration: float) -> bool:
	if not _alive or _root_immune_left > 0.0:
		return false
	var was_stopped: bool = slow.is_stopped()
	_rooted = not was_stopped
	apply_slow(0.0, duration)
	_root_immune_left = duration + STATUS.root_immunity_time
	if _rooted:
		_pop_overlay(_hold_fx)
	return true


func is_rooted() -> bool:
	return _rooted and slow.is_stopped()


## Eingefroren oder festgehalten: kein Laufen, kein Angriff, kein Kontaktschaden.
func is_stopped() -> bool:
	return slow.is_stopped()


func _update_statuses(delta: float) -> void:
	if _root_immune_left > 0.0:
		_root_immune_left -= delta
	if slow.is_active():
		slow.tick(delta)
		if not slow.is_active():
			_rooted = false
			_update_tint()
		elif not _rooted:
			_frost_particle_left -= delta
			if _frost_particle_left <= 0.0:
				_frost_particle_left = STATUS.frost_particle_interval
				Fx.particles(get_tree(), ParticleFx.Kind.FROST, get_hit_position())
	if curse.is_active():
		var damage: int = curse.tick(delta)
		if not curse.is_active():
			_on_curse_ended()
		if damage > 0:
			take_damage(DamageInfo.create(damage, false, 0.0, null, _curse_origin))


func _on_curse_ended() -> void:
	if is_in_group(CURSED_GROUP):
		remove_from_group(CURSED_GROUP)
	_curse_marker.show_stacks(0)
	_update_tint()


func _clear_statuses() -> void:
	curse.clear()
	slow.clear()
	_burn_ticks_left = 0
	_rooted = false
	_root_immune_left = 0.0
	if _curse_marker != null:
		_on_curse_ended()
	else:
		_update_tint()


## Farbton nach Priorität: Frost vor Brand vor Fluch. Dazu Flammen, Eis oder Ranken als eigene Grafik.
func _update_tint() -> void:
	if _burn_fx != null:
		_burn_fx.visible = is_burning()
		_hold_fx.visible = slow.is_stopped()
		_hold_fx.texture = ROOT_TEXTURE if _rooted else ICE_TEXTURE
	var tint: Color = NO_TINT
	if slow.is_active() and not _rooted:
		tint = STATUS.frost_tint
	elif is_burning():
		tint = COMBAT.burn_tint
	elif curse.is_active():
		tint = STATUS.curse_tint
	for mat: ShaderMaterial in [_flash_material, _buff_material]:
		if mat != null:
			mat.set_shader_parameter(TINT_PARAM, tint)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_update_burn(delta)
	_update_statuses(delta)
	if not _alive:
		return
	if _burn_fx.visible:
		var wave_t: float = Time.get_ticks_msec() * 0.001 * STATUS.burn_flicker_speed + get_instance_id() % 7
		_burn_fx.scale = _burn_fx_scale * Vector2(1.0 - STATUS.burn_flicker_amount * 0.5 * sin(wave_t), 1.0 + STATUS.burn_flicker_amount * sin(wave_t))
	if slow.is_stopped():
		_move_knockback_only(delta)
		return
	var move: Vector2 = _behavior.get_velocity(delta) * slow.speed_factor()
	velocity = move + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, COMBAT.knockback_friction * delta)
	global_position += velocity * delta
	if arena_bounds.has_area():
		var margin: Vector2 = Vector2.ONE * data.collision_radius
		global_position = global_position.clamp(arena_bounds.position + margin, arena_bounds.end - margin)
	if absf(move.x) > 0.0:
		_sprite.flip_h = move.x < 0.0
	Juice.walk_tilt(visual, move)
	if not player.is_dead and global_position.distance_to(player.global_position) < _contact_distance:
		player.take_hit(damage)


## Eingefroren: nur Rückstoß bewegt den Gegner, Verhalten und Kontaktschaden ruhen.
func _move_knockback_only(delta: float) -> void:
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, COMBAT.knockback_friction * delta)
	global_position += knockback_velocity * delta
	if arena_bounds.has_area():
		var margin: Vector2 = Vector2.ONE * data.collision_radius
		global_position = global_position.clamp(arena_bounds.position + margin, arena_bounds.end - margin)


func _pop_overlay(overlay: Sprite2D) -> void:
	if overlay != null and overlay.is_inside_tree():
		Juice.spawn_pop(overlay)


func _on_spawned() -> void:
	if _alive:
		Juice.idle_bob(visual)


func _release() -> void:
	if pool != null:
		pool.release(self)
	else:
		queue_free()
