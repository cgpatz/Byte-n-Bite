extends AudioStreamPlayer
## Background music for the whole game. Created by SettingsManager on startup,
## so it keeps playing across scenes (main menu, restaurant) and while paused.
## Volume follows the Music slider in Settings (the "Music" audio bus).

const TRACK := "res://assets/audio/music/bgm_cafe.mp3"
## Volume while playing (dB). Lower = quieter under sound effects.
const PLAY_DB := -6.0
const FADE_IN := 2.0


func _ready() -> void:
	bus = &"Music"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ResourceLoader.exists(TRACK):
		return
	var s := load(TRACK)
	if s is AudioStreamMP3:
		s.loop = true
	elif s is AudioStreamOggVorbis:
		s.loop = true
	stream = s
	volume_db = -40.0
	play()
	create_tween().tween_property(self, "volume_db", PLAY_DB, FADE_IN)
