extends Node
## Sfx: chiptune sound effects and the mute toggle.
## WAVs are synthesized by tools/gen_sfx.py and committed under assets/sfx.
## Missing files fail soft so the game keeps running silently.

const SOUNDS := {
	"panel_open": "res://assets/sfx/panel_open.wav",
	"page": "res://assets/sfx/page.wav",
	"correct": "res://assets/sfx/correct.wav",
	"wrong": "res://assets/sfx/wrong.wav",
	"blip": "res://assets/sfx/blip.wav",
	"fanfare": "res://assets/sfx/fanfare.wav",
	"glitch": "res://assets/sfx/glitch.wav",
}
const POOL_SIZE := 6

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for key in SOUNDS:
		var path: String = SOUNDS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		toggle_mute()


func play(key: String, volume_db: float = 0.0) -> void:
	if GameState.muted or not _streams.has(key):
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[key]
	p.volume_db = volume_db
	p.play()


func toggle_mute() -> void:
	GameState.muted = not GameState.muted
	GameState.save()
	Toasts.show_toast("Sound muted" if GameState.muted else "Sound on")
