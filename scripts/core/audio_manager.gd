extends Node
## Zentrale Wiedergabe von Musik und Soundeffekten (Autoload "AudioManager").
## Effekte laufen über den Bus "SFX", Musik über "Music". Gleichzeitige gleiche Effekte werden begrenzt,
## jede Wiedergabe bekommt eine leichte Tonhöhen-Variation, Funken-Serien steigen in der Tonhöhe.

const CONFIG: AudioConfig = preload("res://data/config/audio_config.tres")
const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
const SOUND_EXTENSION: String = "wav"
const IMPORT_SUFFIXES: PackedStringArray = [".import", ".remap"]
const META_SOUND: StringName = &"sound_id"
const HEADLESS_DISPLAY: String = "headless"
## Beim Beenden: so lange auf den Mixer-Thread warten, bis gestoppte Wiedergaben wirklich freigegeben sind.
const QUIT_DELAY: float = 0.1

var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _spark_pitch: float = 1.0
var _last_spark_time: float = -INF
## Effekte abspielen? Headless (Checks, Tests) nicht: Es gibt keinen Ton, und Wiedergaben, die beim Beenden
## noch laufen, hält der AudioServer fest ("ObjectDB instances leaked"). Tests schalten es gezielt ein.
var output_enabled: bool = true
var _quitting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_enabled = DisplayServer.get_name() != HEADLESS_DISPLAY
	# Fenster schließen läuft über quit_game(), damit laufende Effekte vorher sauber enden.
	get_tree().auto_accept_quit = false
	_load_sounds()
	for i in CONFIG.player_pool_size:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.volume_db = CONFIG.music_volume_db
	add_child(_music_player)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Spiel beenden: alle Wiedergaben stoppen und dem Mixer-Thread Zeit geben, sie freizugeben.
## stop() wirkt asynchron; ohne die Wartezeit hält der AudioServer beim Beenden noch Streams fest.
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	stop_all()
	await get_tree().create_timer(QUIT_DELAY, true, false, true).timeout
	get_tree().quit()


func stop_all() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()
	_music_player.stop()


## Beim Beenden laufende Wiedergaben stoppen und Streams freigeben (sonst hängen Referenzen über das Spielende).
func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
	_music_player.stop()
	_music_player.stream = null
	_streams.clear()


func has_sound(id: StringName) -> bool:
	return _streams.has(id)


## Spielt einen Effekt (Dateiname ohne Endung aus CONFIG.sfx_folder).
func play(id: StringName, pitch_scale: float = 1.0, vary_pitch: bool = true) -> void:
	# Nach _exit_tree (Spielende) nichts mehr starten, sonst bleibt die Wiedergabe als Leak hängen
	if not is_inside_tree() or not output_enabled or _quitting:
		return
	var stream: AudioStream = _streams.get(id)
	if stream == null or _count_playing(id) >= CONFIG.max_instances.get(id, CONFIG.default_max_instances):
		return
	var player: AudioStreamPlayer = _free_player()
	if player == null:
		return
	var variation: float = randf_range(-CONFIG.pitch_variation, CONFIG.pitch_variation) if vary_pitch else 0.0
	player.stream = stream
	player.pitch_scale = maxf(0.01, pitch_scale * (1.0 + variation))
	player.volume_db = CONFIG.sfx_volume_db.get(id, 0.0)
	player.set_meta(META_SOUND, id)
	player.play()


## Funke aufgehoben: innerhalb des Serienfensters steigt die Tonhöhe, sonst beginnt sie von vorn.
func play_spark() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_spark_time <= CONFIG.spark_series_window:
		_spark_pitch = minf(CONFIG.spark_pitch_max, _spark_pitch + CONFIG.spark_pitch_step)
	else:
		_spark_pitch = 1.0
	_last_spark_time = now
	play(&"spark", _spark_pitch, false)


func play_music(stream: AudioStream = null) -> void:
	var target: AudioStream = stream if stream != null else CONFIG.music
	if target == null or (_music_player.stream == target and _music_player.playing):
		return
	# Headless (Tests, CI) gibt keinen Ton aus; der stumme Treiber räumt laufende Musik beim Beenden nicht ab.
	if DisplayServer.get_name() == HEADLESS_DISPLAY:
		return
	var wav: AudioStreamWAV = target as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	_music_player.stream = target
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func _load_sounds() -> void:
	for file_name: String in DirAccess.get_files_at(CONFIG.sfx_folder):
		for suffix: String in IMPORT_SUFFIXES:
			file_name = file_name.trim_suffix(suffix)
		if file_name.get_extension() != SOUND_EXTENSION:
			continue
		var id: StringName = StringName(file_name.get_basename())
		if not _streams.has(id):
			_streams[id] = load(CONFIG.sfx_folder.path_join(file_name))


func _count_playing(id: StringName) -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _players:
		if player.playing and player.get_meta(META_SOUND, &"") == id:
			count += 1
	return count


func _free_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
	return null
