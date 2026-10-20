extends Node
## Zentrale Wiedergabe von Musik und Soundeffekten (Autoload "AudioManager").
## Wird in einer späteren Phase um SFX-Pool und Lautstärke-Optionen erweitert.

var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)


func play_music(stream: AudioStream) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
