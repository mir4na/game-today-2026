class_name TrainAmbience
extends AudioStreamPlayer
## Layered train audio: procedural ambience plus authored rail and brake SFX.

const DEPARTURE_MOTION_THRESHOLD: float = 0.025
const BRAKE_MOTION_THRESHOLD: float = 0.985
const ARRIVAL_STOP_THRESHOLD: float = 0.005

@export_range(-40.0, 6.0, 0.5) var train_sfx_volume_db: float = -11.0
@export_range(-40.0, 6.0, 0.5) var brake_sfx_volume_db: float = -5.0
@export_range(-40.0, 6.0, 0.5) var announcement_sfx_volume_db: float = -3.0
@export_range(-40.0, 6.0, 0.5) var night_ambience_volume_db: float = -12.0

var night_strength: float = 0.0:
	set(value):
		night_strength = clampf(value, 0.0, 1.0)
		_update_night_ambience_volume()
var motion_strength: float = 1.0:
	set(value):
		var previous_strength: float = motion_strength
		motion_strength = clampf(value, 0.0, 1.0)
		_update_authored_train_volume()
		_handle_station_motion(previous_strength, motion_strength)
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _mix_rate: float
var _station_sequence_active: bool = false
var _brake_played: bool = false
var _announcement_played: bool = false
var _departure_restarted: bool = false
var _audio_enabled: bool = false

@onready var _train_sfx: AudioStreamPlayer = $TrainSfx
@onready var _brake_sfx: AudioStreamPlayer = $BrakeSfx
@onready var _announcement_sfx: AudioStreamPlayer = $AnnouncementSfx
@onready var _night_ambience: AudioStreamPlayer = $NightAmbience

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_audio_enabled = true
	_configure_train_sfx_loop()
	_configure_night_ambience_loop()
	_update_authored_train_volume()
	_update_night_ambience_volume()
	restart_train_sfx()
	_night_ambience.play(0.0)
	var generator := stream as AudioStreamGenerator
	if generator == null:
		push_error("TrainAmbience requires an AudioStreamGenerator assigned in its scene.")
		set_process(false)
		return
	_mix_rate = generator.mix_rate
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback

func begin_station_sequence() -> void:
	_station_sequence_active = true
	_brake_played = false
	_announcement_played = false
	_departure_restarted = false
	if _audio_enabled:
		_announcement_sfx.stop()

func end_station_sequence() -> void:
	_station_sequence_active = false
	if _audio_enabled:
		_brake_sfx.stop()

func is_announcement_playing() -> bool:
	return _audio_enabled and _announcement_sfx.playing

func restart_train_sfx() -> void:
	if not _audio_enabled or _train_sfx.stream == null:
		return
	_train_sfx.stop()
	_train_sfx.play(0.0)

func pause_train_travel() -> void:
	motion_strength = 0.0
	if _audio_enabled:
		_train_sfx.stop()

func resume_train_travel() -> void:
	motion_strength = 1.0
	restart_train_sfx()

func _configure_train_sfx_loop() -> void:
	var ogg_stream := _train_sfx.stream as AudioStreamOggVorbis
	if ogg_stream == null:
		return
	ogg_stream = ogg_stream.duplicate() as AudioStreamOggVorbis
	ogg_stream.loop = true
	_train_sfx.stream = ogg_stream

func _configure_night_ambience_loop() -> void:
	var ogg_stream := _night_ambience.stream as AudioStreamOggVorbis
	if ogg_stream == null:
		return
	ogg_stream = ogg_stream.duplicate() as AudioStreamOggVorbis
	ogg_stream.loop = true
	_night_ambience.stream = ogg_stream

func _update_authored_train_volume() -> void:
	if not is_node_ready():
		return
	var audible_strength: float = smoothstep(0.0, 0.18, motion_strength)
	_train_sfx.volume_db = train_sfx_volume_db + linear_to_db(maxf(audible_strength, 0.001))

func _update_night_ambience_volume() -> void:
	if not is_node_ready():
		return
	var fade_strength: float = smoothstep(0.08, 0.85, night_strength)
	_night_ambience.volume_db = night_ambience_volume_db + linear_to_db(maxf(fade_strength, 0.0004))

func _handle_station_motion(previous_strength: float, current_strength: float) -> void:
	if not _station_sequence_active or not _audio_enabled:
		return
	if not _brake_played and previous_strength >= BRAKE_MOTION_THRESHOLD and current_strength < BRAKE_MOTION_THRESHOLD:
		_brake_played = true
		_brake_sfx.volume_db = brake_sfx_volume_db
		_brake_sfx.stop()
		_brake_sfx.play(0.0)
	if not _announcement_played and previous_strength > ARRIVAL_STOP_THRESHOLD and current_strength <= ARRIVAL_STOP_THRESHOLD:
		_announcement_played = true
		_announcement_sfx.volume_db = announcement_sfx_volume_db
		_announcement_sfx.stop()
		_announcement_sfx.play(0.0)
	if not _departure_restarted and previous_strength <= DEPARTURE_MOTION_THRESHOLD and current_strength > DEPARTURE_MOTION_THRESHOLD:
		_departure_restarted = true
		restart_train_sfx()

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	for i: int in range(frames):
		var movement: float = clampf(motion_strength, 0.0, 1.0)
		var base_frequency: float = lerpf(48.0, 34.0, night_strength) * lerpf(0.45, 1.0, movement)
		var rumble: float = sin(_phase * TAU * base_frequency) * lerpf(0.035, 0.018, night_strength) * movement
		var rail_click: float = 0.012 if movement > 0.18 and fmod(_phase, 0.72) < 0.018 else 0.0
		var wind: float = sin(_phase * TAU * 0.38) * 0.008 * night_strength * movement
		var sample: float = rumble + rail_click + wind + randf_range(-0.004, 0.004) * movement
		_playback.push_frame(Vector2(sample, sample))
		_phase += 1.0 / _mix_rate

func _exit_tree() -> void:
	_train_sfx.stop()
	_brake_sfx.stop()
	_announcement_sfx.stop()
	_night_ambience.stop()
	stop()
	_playback = null
	stream = null
