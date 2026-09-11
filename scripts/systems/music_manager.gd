extends Node
## Global music manager — handles BGM crossfade across scenes.
## Registered as an AutoLoad so it persists and never leaks audio between scenes.

@export_category("Scene-Authored Tracks")
@export var main_menu_stream: AudioStream
@export var intro_stream: AudioStream
@export var gameplay_day_stream: AudioStream
@export var gameplay_night_stream: AudioStream
@export var heaven_outro_stream: AudioStream
@export var bad_ending_outro_stream: AudioStream
@export_category("Mix")
@export_range(0.0, 1.0, 0.01) var music_volume: float = 0.5
@export_range(0.2, 3.0, 0.1) var fade_duration: float = 1.2

var _current_track: StringName = &""
var _fade_tween: Tween

@onready var _player_a: AudioStreamPlayer = $PlayerA
@onready var _player_b: AudioStreamPlayer = $PlayerB
var _active_player: AudioStreamPlayer


func _ready() -> void:
	# Keep this node alive across all scene changes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a.bus = &"Master"
	_player_b.bus = &"Master"
	_player_a.volume_db = _music_volume_db()
	_player_b.volume_db = _music_volume_db()
	_active_player = _player_a


## Play a named track. If it is already playing nothing happens.
## Pass loop=false for one-shot tracks like endings.
func play(track_id: StringName, loop: bool = true) -> void:
	if track_id == _current_track:
		return
	var stream: AudioStream = _stream_for_track(track_id)
	if stream == null:
		push_warning("MusicManager: unknown track '%s'" % track_id)
		return

	# Set loop flag on the stream if supported.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop

	_current_track = track_id
	_crossfade_to(stream)


## Stop music with a fade out.
func stop() -> void:
	if _current_track == &"":
		return
	_current_track = &""
	_kill_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(
		_active_player, ^"volume_db", _music_volume_db() - 60.0, fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(_active_player.stop)
	_fade_tween.tween_callback(func() -> void: _active_player.volume_db = _music_volume_db())


## --- internals ---

func _crossfade_to(stream: AudioStream) -> void:
	_kill_tween()

	# Pick the idle player as the incoming one.
	var incoming: AudioStreamPlayer = (
		_player_b if _active_player == _player_a else _player_a
	)
	var outgoing: AudioStreamPlayer = _active_player

	incoming.stream = stream
	incoming.volume_db = _music_volume_db() - 60.0
	incoming.play()

	_active_player = incoming

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	# Fade in incoming.
	_fade_tween.tween_property(
		incoming, ^"volume_db", _music_volume_db(), fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Fade out outgoing.
	_fade_tween.tween_property(
		outgoing, ^"volume_db", _music_volume_db() - 60.0, fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Stop outgoing after fade and reset its volume for next use.
	_fade_tween.chain().tween_callback(outgoing.stop)
	_fade_tween.tween_callback(func() -> void: outgoing.volume_db = _music_volume_db())


func _stream_for_track(track_id: StringName) -> AudioStream:
	match track_id:
		&"main_menu":
			return main_menu_stream
		&"intro":
			return intro_stream
		&"gameplay_day":
			return gameplay_day_stream
		&"gameplay_night":
			return gameplay_night_stream
		&"ending_good":
			return heaven_outro_stream
		&"ending_bad":
			return bad_ending_outro_stream
	return null


func _music_volume_db() -> float:
	return linear_to_db(clampf(music_volume, 0.0001, 1.0))


func _kill_tween() -> void:
	if is_instance_valid(_fade_tween) and _fade_tween.is_valid():
		_fade_tween.kill()
