class_name Weapon
extends Node2D
## Eine schwebende Waffe: sucht das nächste Ziel in Reichweite, dreht sich hin und greift mit eigener Abklingzeit an.
## Nahkampf: Stoß oder Schwung mit Hitbox, trifft mehrere Gegner. Fernkampf: gepoolte Projektile.

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const HUD: HudConfig = preload("res://data/config/hud_config.tres")
const OUTLINE_SHADER: Shader = preload("res://art/shaders/outline.gdshader")
const OUTLINE_COLOR_PARAM: StringName = &"outline_color"
const OUTLINE_WIDTH_PARAM: StringName = &"outline_width"

var data: WeaponData
var tier: int = WeaponData.MIN_TIER
var player: Player
## Ruheposition relativ zu den WeaponSlots (vom Slot-Layout gesetzt).
var rest_position: Vector2 = Vector2.ZERO
## Spiegelbild-Kopie: weniger Schaden, kein Lebensraub, löst keine Angriffs-Effekte aus.
var is_clone: bool = false
var damage_factor: float = 1.0

var _cooldown_left: float = 0.0
var _retarget_left: float = 0.0
var _target: Damageable
var _aim_angle: float = 0.0
var _attacking: bool = false
var _attack_info: DamageInfo
var _hit_ids: Dictionary[int, bool] = {}

@onready var _sprite: Sprite2D = $Sprite
@onready var _hitbox: Area2D = $Hitbox
@onready var _hitbox_shape: CollisionShape2D = $Hitbox/Shape


func setup(p_data: WeaponData, p_tier: int, p_player: Player) -> void:
	data = p_data
	tier = p_tier
	player = p_player
	if is_node_ready():
		_apply_data()


func _ready() -> void:
	_hitbox.monitoring = false
	(_hitbox_shape.shape as CircleShape2D).radius = COMBAT.melee_hitbox_radius
	if data != null:
		_apply_data()


func _apply_data() -> void:
	_sprite.texture = data.texture
	_sprite.rotation = deg_to_rad(data.sprite_rotation_deg)
	_sprite.material = tier_outline_material(tier)


## Kontur in der Tier-Farbe, damit das Tier auch im Getümmel erkennbar ist.
static func tier_outline_material(p_tier: int) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	var color: Color = UiStyle.tier_color(p_tier)
	color.a = HUD.weapon_outline_alpha
	material.set_shader_parameter(OUTLINE_COLOR_PARAM, color)
	material.set_shader_parameter(OUTLINE_WIDTH_PARAM, HUD.weapon_outline_width)
	return material


func get_tier_stats() -> WeaponTierStats:
	return data.get_tier(tier)


## Grundschaden des Tiers plus Bonus für gleiche Waffen (vor Skalierung und Schaden-%).
func get_base_damage() -> float:
	var base: float = get_tier_stats().base_damage
	if data.damage_per_same_weapon != 0.0:
		base += data.damage_per_same_weapon * (player.weapon_slots.count_of(data.id) - 1)
	return base


func get_range() -> float:
	var range_stat: float = player.stats.get_stat(Stats.RANGE) + player.class_bonus(Stats.RANGE, data.classes)
	return CombatMath.effective_range(get_tier_stats().range, range_stat, data.is_melee())


func get_cooldown() -> float:
	var attack_speed: float = player.stats.get_stat(Stats.ATTACK_SPEED) + player.class_bonus(Stats.ATTACK_SPEED, data.classes)
	return CombatMath.attack_cooldown(get_tier_stats().cooldown, attack_speed)


func is_attacking() -> bool:
	return _attacking


func _physics_process(delta: float) -> void:
	if player == null or data == null or player.is_dead:
		return
	_cooldown_left -= delta
	if _attacking:
		_process_melee_hits()
		return
	_retarget_left -= delta
	if _retarget_left <= 0.0 or not _is_valid_target(_target):
		_target = _find_target()
		_retarget_left = COMBAT.target_refresh_interval
	if player.manual_aim:
		_aim(player.get_aim_direction().angle())
		if _target == null:
			return
	elif _target == null:
		_aim(rest_position.angle())
		return
	else:
		_aim((_target.get_hit_position() - global_position).angle())
	if _cooldown_left <= 0.0:
		_cooldown_left = get_cooldown()
		if not is_clone:
			player.weapon_attacked.emit(self, _target)
		if data.kind == WeaponData.Kind.RANGED:
			_fire()
		else:
			_melee()


func _is_valid_target(enemy: Damageable) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return false
	var reach: float = get_range()
	return global_position.distance_squared_to(enemy.get_hit_position()) <= reach * reach


func _find_target() -> Damageable:
	var reach_sq: float = get_range() * get_range()
	var best: Damageable = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group(Damageable.GROUP):
		var enemy: Damageable = node as Damageable
		if enemy == null or not enemy.is_alive():
			continue
		var dist: float = global_position.distance_squared_to(enemy.get_hit_position())
		if dist <= reach_sq and dist < best_dist:
			best = enemy
			best_dist = dist
	return best


func _aim(angle: float) -> void:
	_aim_angle = angle
	rotation = angle
	scale.y = -1.0 if absf(angle) > PI * 0.5 else 1.0


## Würfelt Krit und berechnet den Schaden für einen Angriff.
func _roll_damage() -> DamageInfo:
	var t: WeaponTierStats = get_tier_stats()
	var s: StatSystem = player.stats
	var base: float = get_base_damage()
	var crit: bool = not player.has_rule(Player.Rule.NO_CRIT) 		and player.rng.randf() < CombatMath.crit_chance(t.crit_chance, s.get_stat(Stats.CRIT_CHANCE))
	var amount: int = CombatMath.weapon_damage(
		base, CombatMath.scaling_bonus(t.scalings, s), s.get_stat(Stats.DAMAGE_PCT), t.crit_multiplier if crit else 1.0)
	if damage_factor != 1.0:
		amount = maxi(CombatMath.MIN_DAMAGE, roundi(amount * damage_factor))
	var info: DamageInfo = DamageInfo.create(amount, crit, t.knockback + s.get_stat(Stats.KNOCKBACK), self, DamageSource.weapon(data.id))
	info.burn_damage = t.burn_damage
	info.burn_ticks = t.burn_ticks
	info.burn_chance = t.burn_chance
	info.root_chance = t.root_chance
	info.root_duration = t.root_duration
	info.extra_souls = t.extra_souls
	info.heal_on_hit_chance = t.heal_on_hit_chance
	info.spark_on_kill_chance = t.spark_on_kill_chance
	return info


# --- Fernkampf ---

func _fire() -> void:
	var pool: ObjectPool = Pools.get_pool(get_tree(), Pools.PLAYER_PROJECTILES)
	if pool == null:
		return
	var t: WeaponTierStats = get_tier_stats()
	var count: int = maxi(1, t.projectile_count)
	var spread: float = deg_to_rad(t.spread_deg)
	var piercing: int = t.piercing + roundi(player.stats.get_stat(Stats.PIERCING))
	var bounces: int = t.bounces + roundi(player.stats.get_stat(Stats.BOUNCES))
	for i in count:
		var angle: float = _aim_angle
		if count > 1:
			angle += lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		elif spread > 0.0:
			angle += player.rng.randf_range(-spread * 0.5, spread * 0.5)
		var spec: ProjectileSpec = ProjectileSpec.new()
		spec.texture = data.projectile_texture
		spec.speed = data.projectile_speed
		spec.max_range = get_range()
		spec.info = _roll_damage()
		spec.piercing = piercing
		spec.bounces = bounces
		spec.chain_count = t.chain_count
		spec.chain_range = t.chain_range
		spec.explosion_radius = t.explosion_radius
		spec.homing_turn_deg = t.homing_turn_deg
		spec.split_count = t.split_count
		spec.split_damage_pct = t.split_damage_pct
		spec.split_texture = data.split_projectile_texture
		spec.player = player
		spec.lifesteal = not is_clone
		(pool.acquire() as Projectile).launch(global_position + Vector2.from_angle(angle) * COMBAT.muzzle_offset, angle, spec)
	AudioManager.play(&"shoot")
	var muzzle: Vector2 = global_position + Vector2.from_angle(_aim_angle) * COMBAT.muzzle_offset
	Fx.particles(get_tree(), ParticleFx.Kind.MUZZLE, muzzle, Vector2.from_angle(_aim_angle))
	_recoil()


func _recoil() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "position:x", -COMBAT.recoil_distance, COMBAT.recoil_time * 0.3)
	tween.tween_property(_sprite, "position:x", 0.0, COMBAT.recoil_time * 0.7)


# --- Nahkampf ---

func _melee() -> void:
	AudioManager.play(&"swing")
	_attacking = true
	_hit_ids.clear()
	_attack_info = _roll_damage()
	_hitbox.monitoring = true
	var duration: float = minf(
		COMBAT.melee_attack_time_base + get_range() * COMBAT.melee_attack_time_per_range,
		get_cooldown() * COMBAT.melee_max_cooldown_share)
	var target_local: Vector2 = _attack_point() - get_parent().global_position
	var tween: Tween = create_tween()
	if data.kind == WeaponData.Kind.SWING:
		var radius: float = clampf(target_local.length(), rest_position.length(), get_range())
		var arc: float = deg_to_rad(COMBAT.swing_arc_deg)
		var center: float = target_local.angle()
		tween.tween_method(_swing_step.bind(radius), center - arc * 0.5, center + arc * 0.5, duration * 0.7)
	else:
		tween.tween_property(self, "position", target_local, duration * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", rest_position, duration * 0.6).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_end_melee)


## Zielpunkt des Nahkampfangriffs: der Gegner, beim manuellen Zielen ein Punkt in Zielrichtung.
func _attack_point() -> Vector2:
	if not player.manual_aim:
		return _target.get_hit_position()
	var reach: float = minf(get_range(), global_position.distance_to(_target.get_hit_position()))
	return global_position + Vector2.from_angle(_aim_angle) * reach


func _swing_step(angle: float, radius: float) -> void:
	position = Vector2.from_angle(angle) * radius
	_aim(angle)


func _process_melee_hits() -> void:
	for body: Node2D in _hitbox.get_overlapping_bodies():
		var enemy: Damageable = body as Damageable
		if enemy == null or not enemy.is_alive() or _hit_ids.has(enemy.get_instance_id()):
			continue
		_hit_ids[enemy.get_instance_id()] = true
		_attack_info.knockback_dir = (enemy.global_position - player.global_position).normalized()
		Hits.apply_weapon_hit(enemy, _attack_info, player, not is_clone)


func _end_melee() -> void:
	_attacking = false
	_hitbox.set_deferred("monitoring", false)
	position = rest_position
