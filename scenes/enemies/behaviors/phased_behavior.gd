class_name PhasedBehavior
extends EnemyBehavior
## Elites und Bosse: Phasen mit Bewegung und Angriffsmustern. Wechsel bei HP-Schwelle oder nach Zeit.

enum ChargeState { MOVE, WINDUP, CHARGE }

const PHASE_TELEGRAPH_TIME: float = 0.4

var config: PhasedData
var phase_index: int = 0

var _phase_time: float = 0.0
var _attack_timers: Array[float] = []
var _casts: Array[int] = []
var _charge_state: ChargeState = ChargeState.MOVE
var _charge_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO


func reset() -> void:
	_enter_phase(0)


func current_phase() -> BossPhaseData:
	return config.phases[phase_index]


func get_velocity(delta: float) -> Vector2:
	_phase_time += delta
	_check_transition()
	var phase: BossPhaseData = current_phase()
	for i in phase.attacks.size():
		_attack_timers[i] -= delta
		if _attack_timers[i] <= 0.0:
			_attack_timers[i] = phase.attacks[i].cooldown
			phase.attacks[i].execute(enemy, _casts[i])
			_casts[i] += 1
	var speed: float = enemy.speed * phase.speed_multiplier
	match phase.movement:
		BossPhaseData.Movement.CHASE:
			return enemy.direction_to_player() * speed
		BossPhaseData.Movement.FLEE:
			return -enemy.direction_to_player() * speed
		BossPhaseData.Movement.STAND:
			return Vector2.ZERO
		_:
			return _charge_velocity(phase, speed, delta)


func _charge_velocity(phase: BossPhaseData, speed: float, delta: float) -> Vector2:
	_charge_timer -= delta
	match _charge_state:
		ChargeState.MOVE:
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.WINDUP
				_charge_timer = phase.charge_windup
				Juice.telegraph(enemy.visual, phase.charge_windup)
			return enemy.direction_to_player() * speed
		ChargeState.WINDUP:
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.CHARGE
				_charge_timer = phase.charge_time
				_charge_direction = enemy.direction_to_player()
				if phase.charge_attack != null:
					phase.charge_attack.execute(enemy, 0)
			return Vector2.ZERO
		_:
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.MOVE
				_charge_timer = phase.charge_interval
			return _charge_direction * phase.charge_speed


func _check_transition() -> void:
	if phase_index >= config.phases.size() - 1:
		return
	var phase: BossPhaseData = current_phase()
	var by_hp: bool = phase.next_at_hp > 0.0 and enemy.hp <= enemy.max_hp * phase.next_at_hp
	var by_time: bool = phase.max_duration > 0.0 and _phase_time >= phase.max_duration
	if by_hp or by_time:
		_enter_phase(phase_index + 1)
		Juice.telegraph(enemy.visual, PHASE_TELEGRAPH_TIME)


func _enter_phase(index: int) -> void:
	phase_index = index
	_phase_time = 0.0
	var phase: BossPhaseData = current_phase()
	_attack_timers.clear()
	_casts.clear()
	for attack: AttackPatternData in phase.attacks:
		_attack_timers.append(attack.cooldown * 0.5)
		_casts.append(0)
	_charge_state = ChargeState.MOVE
	_charge_timer = phase.charge_interval
