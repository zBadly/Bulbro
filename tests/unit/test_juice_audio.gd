extends GutTest
## Tests für Sounds, AudioManager-Regeln, Partikel und Bodenflecken (Phase 11).

const EXPECTED_SOUNDS: PackedStringArray = [
	"shoot", "swing", "hit", "hit_crit", "enemy_death", "spark", "level_up", "buy", "reroll",
	"player_hurt", "boss_warning", "explosion", "wave_clear", "heal", "ui_click",
]
const SPLAT_SCENE: PackedScene = preload("res://scenes/fx/splat.tscn")
const CONFIG: AudioConfig = preload("res://data/config/audio_config.tres")


func test_all_generated_sounds_are_loaded() -> void:
	for id: String in EXPECTED_SOUNDS:
		assert_true(AudioManager.has_sound(StringName(id)), "fehlt: " + id)


func test_same_sound_is_limited() -> void:
	AudioManager.output_enabled = true
	for i in 20:
		AudioManager.play(&"hit")
	var playing: int = AudioManager.call("_count_playing", &"hit")
	AudioManager.stop_all()
	AudioManager.output_enabled = false
	assert_gt(playing, 0)
	assert_lte(playing, CONFIG.max_instances[&"hit"])


func test_headless_plays_no_effects() -> void:
	assert_false(AudioManager.output_enabled)
	AudioManager.play(&"hit")
	assert_eq(AudioManager.call("_count_playing", &"hit"), 0)


func test_spark_series_raises_pitch_and_resets() -> void:
	AudioManager.set("_last_spark_time", -INF)
	AudioManager.play_spark()
	var first: float = AudioManager.get("_spark_pitch")
	AudioManager.play_spark()
	AudioManager.play_spark()
	assert_gt(AudioManager.get("_spark_pitch"), first)
	AudioManager.set("_last_spark_time", -INF)
	AudioManager.play_spark()
	assert_eq(AudioManager.get("_spark_pitch"), 1.0)


func test_music_loop_is_a_seamless_placeholder() -> void:
	var music: AudioStreamWAV = CONFIG.music as AudioStreamWAV
	assert_not_null(music)
	assert_almost_eq(music.get_length(), 16.0, 0.1)


func test_audio_buses_exist() -> void:
	for bus: String in ["Master", "Music", "SFX"]:
		assert_gte(AudioServer.get_bus_index(bus), 0, bus)


func test_particles_cycle_emitters() -> void:
	var fx: ParticleFx = ParticleFx.new()
	add_child_autofree(fx)
	for i in ParticleFx.EMITTERS_PER_KIND + 2:
		fx.emit(ParticleFx.Kind.DEATH, Vector2(i, 0))
	assert_eq(fx.get("_next")[ParticleFx.Kind.DEATH], 2)


func test_fx_helpers_are_safe_without_hosts() -> void:
	Fx.particles(get_tree(), ParticleFx.Kind.HIT, Vector2.ZERO)
	Fx.shake(get_tree(), 1.0)
	Fx.hit_stop(get_tree())
	assert_eq(Engine.time_scale, 1.0)


func test_splat_fades_back_to_pool() -> void:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = SPLAT_SCENE
	add_child_autofree(pool)
	var splat: Splat = pool.acquire() as Splat
	splat.show_at(Vector2.ZERO, 20.0, 0.0)
	assert_eq(pool.active_count(), 1)
	await wait_seconds(Splat.HOLD_TIME + Splat.FADE_TIME + 0.2)
	assert_eq(pool.active_count(), 0)


func test_sfx_tool_is_reproducible() -> void:
	assert_true(FileAccess.file_exists("res://tools/make_sfx.py"))
	assert_true(FileAccess.file_exists("res://tools/make_music.py"))
