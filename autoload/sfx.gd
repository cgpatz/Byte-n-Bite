extends Node
## Sound effects (SFX bus, volume from Settings > Sound Effects).
## Sfx.play("coin"). Sounds live in assets/audio/sfx/<name>.wav.
## Hooked up here so gameplay code stays simple: every button clicks, coins
## earned, quests / goals done, level-ups. Staff, HUD and the game call play()
## for cooking, serving, errors, notices and the delivery truck.

const DIR := "res://assets/audio/sfx/"
const VOICES := 6
var _players: Array[AudioStreamPlayer] = []
var _streams := {}
var _last := {}           # name -> time last played (stops machine-gun repeats)
var _money := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)
	var gs := get_node_or_null("/root/GameState")
	if gs:
		_money = gs.money
		gs.money_changed.connect(_on_money)
		gs.player_leveled_up.connect(func(_l, _r): play("levelup"))
		gs.goal_reached.connect(func(_l, _i): play("quest"))
		gs.challenge_completed.connect(func(_l, _i): play("quest"))
		if gs.has_signal("quests_changed"):
			gs.quests_changed.connect(func(): play("quest"))


func play(name: String, volume_db := 0.0, min_gap := 0.08) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -10.0)) < min_gap:
		return
	_last[name] = now
	if not _streams.has(name):
		var path := DIR + name + ".wav"
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	var s: AudioStream = _streams[name]
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.play()
			return
	_players[0].stream = s
	_players[0].volume_db = volume_db
	_players[0].play()


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("no_click_sfx"):
		(n as BaseButton).pressed.connect(func(): play("click", -6.0))


func _on_money(m: int) -> void:
	if _money >= 0 and m > _money:
		play("coin", -3.0, 0.15)
	_money = m
