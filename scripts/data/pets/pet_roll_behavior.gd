class_name PetRollBehavior
extends PetBehavior
## Batterie-Igel: rollt auf den nächsten Gegner in Reichweite um den Spieler, rammt ihn mit Rückstoß und
## rollt weiter, solange Gegner nah genug sind. Ohne Ziel folgt er dem Spieler.

const COOLDOWN_KEY: String = "cooldown"
const TARGET_KEY: String = "target"
const RETARGET_KEY: String = "retarget"

@export var roll_speed: float = 0.0
## Zeit zwischen zwei Zielsuchen in Sekunden.
@export var retarget_interval: float = 0.0


func tick(pet: Pet, delta: float) -> bool:
	pet.state[COOLDOWN_KEY] = float(pet.state.get(COOLDOWN_KEY, 0.0)) - delta
	var retarget: float = float(pet.state.get(RETARGET_KEY, 0.0)) - delta
	var stats: PetTierStats = pet.get_tier_stats()
	var target: Damageable = pet.state.get(TARGET_KEY) as Damageable if is_instance_valid(pet.state.get(TARGET_KEY)) else null
	if retarget <= 0.0 or target == null or not target.is_alive() or not _in_leash(pet, target, stats):
		retarget = retarget_interval
		target = _nearest_enemy(pet, stats)
		pet.state[TARGET_KEY] = target
	pet.state[RETARGET_KEY] = retarget
	if target == null:
		return false
	var to_target: Vector2 = target.get_hit_position() - pet.get_center()
	if to_target.length() > Pet.CONFIG.contact_distance:
		var step: Vector2 = to_target.normalized() * minf(roll_speed * delta, to_target.length())
		pet.move_by(step, delta)
	elif float(pet.state[COOLDOWN_KEY]) <= 0.0:
		pet.state[COOLDOWN_KEY] = stats.cooldown
		var info: DamageInfo = DamageInfo.create(damage(stats, pet.player.stats), false, stats.knockback, pet, pet.get_origin())
		info.knockback_dir = to_target.normalized()
		Hits.apply_weapon_hit(target, info, pet.player, false)
		Juice.effect_flash(pet.sprite)
	return true


func animate_move(pet: Pet, velocity: Vector2, delta: float) -> void:
	Juice.roll(pet.sprite, velocity, delta)


func _in_leash(pet: Pet, target: Damageable, stats: PetTierStats) -> bool:
	return pet.player.get_center().distance_squared_to(target.get_hit_position()) <= stats.range * stats.range


## Nächster Gegner zum Igel, der höchstens `range` vom Spieler entfernt ist (keine neutralen Objekte).
func _nearest_enemy(pet: Pet, stats: PetTierStats) -> Damageable:
	var best: Damageable = null
	var best_dist: float = INF
	for target: Damageable in Hits.alive_targets(pet.get_tree()):
		if not _in_leash(pet, target, stats):
			continue
		var dist: float = pet.get_center().distance_squared_to(target.get_hit_position())
		if dist < best_dist:
			best = target
			best_dist = dist
	return best


func describe(stats: PetTierStats) -> PackedStringArray:
	return [TextFormat.t("PET_ROLL_DESC") % [EffectAction.damage_text(stats.base_damage, stats.scalings),
		seconds(stats.cooldown), TextFormat.number(stats.range), TextFormat.number(stats.knockback)]]


func status_lines(pet: Pet) -> PackedStringArray:
	return [TextFormat.t("TIP_PET_DAMAGE") % damage(pet.get_tier_stats(), pet.player.stats)]
