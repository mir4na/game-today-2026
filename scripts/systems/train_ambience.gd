class_name TrainAmbience
extends AudioStreamPlayer
## Tiny procedural placeholder: low rail rumble by day, thinner wind at night.

var night_strength: float = 0.0
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _mix_rate: float

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	var generator := stream as AudioStreamGenerator
	if generator == null:
		push_error("TrainAmbience requires an AudioStreamGenerator assigned in its scene.")
		set_process(false)
		return
	_mix_rate = generator.mix_rate
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	for i: int in range(frames):
		var base_frequency: float = lerpf(48.0, 34.0, night_strength)
		var rumble: float = sin(_phase * TAU * base_frequency) * lerpf(0.035, 0.018, night_strength)
		var rail_click: float = 0.012 if fmod(_phase, 0.72) < 0.018 else 0.0
		var wind: float = sin(_phase * TAU * 0.38) * 0.008 * night_strength
		var sample: float = rumble + rail_click + wind + randf_range(-0.004, 0.004)
		_playback.push_frame(Vector2(sample, sample))
		_phase += 1.0 / _mix_rate

func _exit_tree() -> void:
	stop()
	_playback = null
	stream = null
