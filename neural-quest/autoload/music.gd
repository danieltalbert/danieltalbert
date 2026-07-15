extends Node
## Music: one looping chiptune track per act with a crossfade at biome
## borders. Follows the shared mute flag. Missing files fail soft.

const TRACK_VOLUME_DB := -14.0
const FADE_SECONDS := 1.4

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current_act := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


func _process(_delta: float) -> void:
	# Mute ducks the whole music layer without losing playback position.
	for p in _players:
		p.stream_paused = GameState.muted


func set_act(act_id: int) -> void:
	if act_id == _current_act:
		return
	_current_act = act_id
	var path := "res://assets/music/act%d.wav" % act_id
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2  # 16-bit mono frames

	var fade_out := _players[_active]
	_active = 1 - _active
	var fade_in := _players[_active]
	fade_in.stream = stream
	fade_in.volume_db = -60.0
	fade_in.play()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fade_in, "volume_db", TRACK_VOLUME_DB, FADE_SECONDS)
	tw.tween_property(fade_out, "volume_db", -60.0, FADE_SECONDS)
	tw.chain().tween_callback(fade_out.stop)


func stop() -> void:
	_current_act = 0
	for p in _players:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, FADE_SECONDS)
		tw.tween_callback(p.stop)
