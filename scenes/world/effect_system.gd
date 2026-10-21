class_name EffectSystem
extends Node
## Ruft die beim Spieler registrierten Trigger-Effekte bei Ereignissen auf (Kill, Treffer, Funke, Wellen-Tick,
## Waffenangriff, Waffentreffer, Überheilung, Wellenende).

var player: Player:
	set(value):
		player = value
		_ctx = EffectContext.create(player)
		player.damaged.connect(_on_player_damaged)
		player.weapon_attacked.connect(_on_weapon_attacked)
		player.enemy_hit.connect(_on_enemy_hit)
		player.overhealed.connect(_on_overhealed)

var _ctx: EffectContext


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.spark_collected.connect(_on_spark_collected)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_ended.connect(_on_wave_ended)
	Events.burning_enemy_killed.connect(_on_burning_enemy_killed)


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead or GameState.phase != GameState.Phase.WAVE:
		return
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_wave_tick(_ctx, entry, delta)


func _on_enemy_killed(data: EnemyData, position: Vector2, info: DamageInfo) -> void:
	if player == null:
		return
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_enemy_killed(_ctx, entry, position, data, info)


func _on_player_damaged(_amount: int) -> void:
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_hit_taken(_ctx, entry)


func _on_spark_collected() -> void:
	if player == null:
		return
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_spark_collected(_ctx, entry)


func _on_wave_started(_wave_number: int) -> void:
	if player == null:
		return
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_wave_started(_ctx, entry)


func _on_wave_ended(_wave_number: int) -> void:
	if player == null:
		return
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_wave_ended(_ctx, entry)


func _on_weapon_attacked(weapon: Weapon, target: Damageable) -> void:
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_weapon_attack(_ctx, entry, weapon, target)


func _on_enemy_hit(target: Damageable, info: DamageInfo) -> void:
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_enemy_hit(_ctx, entry, target, info)


func _on_burning_enemy_killed(position: Vector2) -> void:
	if player == null:
		return
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_burning_enemy_killed(_ctx, entry, position)


func _on_overhealed(amount: float) -> void:
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_overheal(_ctx, entry, amount)
