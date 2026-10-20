class_name EffectSystem
extends Node
## Ruft die beim Spieler registrierten Trigger-Effekte bei Ereignissen auf (Kill, Treffer, Funke, Wellen-Tick).

var player: Player:
	set(value):
		player = value
		_ctx = EffectContext.create(player)
		player.damaged.connect(_on_player_damaged)

var _ctx: EffectContext


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.spark_collected.connect(_on_spark_collected)
	Events.wave_started.connect(_on_wave_started)


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead or GameState.phase != GameState.Phase.WAVE:
		return
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_wave_tick(_ctx, entry, delta)


func _on_enemy_killed(_data: EnemyData, position: Vector2, _info: DamageInfo) -> void:
	if player == null:
		return
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_enemy_killed(_ctx, entry, position)


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
