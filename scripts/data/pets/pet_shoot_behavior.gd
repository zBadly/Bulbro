class_name PetShootBehavior
extends PetBehavior
## Leuchtkäfer: kreist um seinen Ruheplatz, flattert und schießt mit eigener Abklingzeit auf das nächste Ziel.

const COOLDOWN_KEY: String = "cooldown"
const NO_EXCLUDE: Dictionary[int, bool] = {}

@export var projectile_texture: Texture2D
@export var projectile_speed: float = 0.0
## Kreisen um den Ruheplatz: Radius und Winkelgeschwindigkeit.
@export var orbit_radius: float = 0.0
@export var orbit_speed_deg: float = 0.0


func start(pet: Pet) -> void:
	Juice.flutter(pet.visual)


func follow_offset(pet: Pet, time: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(orbit_speed_deg) * time + PI * pet.slot_index) * orbit_radius


func animate_move(pet: Pet, velocity: Vector2, _delta: float) -> void:
	pet.sprite.flip_h = velocity.x < 0.0


func tick(pet: Pet, delta: float) -> bool:
	var left: float = float(pet.state.get(COOLDOWN_KEY, 0.0)) - delta
	pet.state[COOLDOWN_KEY] = left
	if left > 0.0:
		return false
	var stats: PetTierStats = pet.get_tier_stats()
	var target: Damageable = Hits.nearest_target(pet.get_tree(), pet.get_center(), stats.range, NO_EXCLUDE)
	if target == null:
		return false
	pet.state[COOLDOWN_KEY] = stats.cooldown
	_fire(pet, stats, target)
	return false


func _fire(pet: Pet, stats: PetTierStats, target: Damageable) -> void:
	var pool: ObjectPool = Pools.get_pool(pet.get_tree(), Pools.PLAYER_PROJECTILES)
	if pool == null:
		return
	var spec: ProjectileSpec = ProjectileSpec.new()
	spec.texture = projectile_texture
	spec.speed = projectile_speed
	spec.max_range = stats.range
	spec.info = DamageInfo.create(damage(stats, pet.player.stats), false, stats.knockback, pet, pet.get_origin())
	spec.player = pet.player
	spec.lifesteal = false
	var start: Vector2 = pet.get_center()
	(pool.acquire() as Projectile).launch(start, start.direction_to(target.get_hit_position()).angle(), spec)
	Fx.particles(pet.get_tree(), ParticleFx.Kind.MUZZLE, start, start.direction_to(target.get_hit_position()))


func describe(stats: PetTierStats) -> PackedStringArray:
	return [TextFormat.t("PET_SHOOT_DESC") % [EffectAction.damage_text(stats.base_damage, stats.scalings),
		seconds(stats.cooldown), TextFormat.number(stats.range)]]


func status_lines(pet: Pet) -> PackedStringArray:
	return [TextFormat.t("TIP_PET_DAMAGE") % damage(pet.get_tier_stats(), pet.player.stats)]
