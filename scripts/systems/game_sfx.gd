class_name GameSFX
extends Node

const SOUNDS: Dictionary = {
	&"carriage_creak": preload("res://assets/sfx/carriage_creak.ogg"),
	&"button_hover": preload("res://assets/sfx/button_hover.mp3"),
	&"clock_ticking": preload("res://assets/sfx/clock_ticking.ogg"),
	&"coin_flip": preload("res://assets/sfx/coin_flip.ogg"),
	&"footstep": preload("res://assets/sfx/footstep.mp3"),
	&"ghost_whisper": preload("res://assets/sfx/ghost_whisper.ogg"),
	&"grab": preload("res://assets/sfx/grab.ogg"),
	&"magic_shimmer": preload("res://assets/sfx/magic_shimmer.ogg"),
	&"mechanical_door": preload("res://assets/sfx/mechanical_door.ogg"),
	&"paper_rustle": preload("res://assets/sfx/paper_rustle.ogg"),
	&"radar_ping": preload("res://assets/sfx/radar_ping.ogg"),
	&"speed_woosh": preload("res://assets/sfx/speed_woosh.ogg"),
	&"stamp_impact": preload("res://assets/sfx/stamp_impact.ogg"),
	&"success": preload("res://assets/sfx/success.ogg"),
	&"time_warp": preload("res://assets/sfx/time_warp.ogg"),
	&"typewriter": preload("res://assets/sfx/typewriter.ogg"),
	&"ui_confirm": preload("res://assets/sfx/ui_confirm.ogg"),
	&"ui_error": preload("res://assets/sfx/ui_error.ogg"),
	&"wipe": preload("res://assets/sfx/wipe.ogg"),
}

const POOL_SIZE := 20
const BUTTON_META := &"game_sfx_connected"
const BUTTON_CONFIRM_SUPPRESS_META := &"suppress_global_confirm_sfx"

var _players: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}
var _cooldown_until: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_rng.randomize()
	if _silent:
		return
	for index: int in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "OneShot%02d" % index
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	get_tree().node_added.connect(_on_node_added)
	call_deferred(&"_register_existing_buttons")


static func play(sound_id: StringName, volume_db: float = 0.0, pitch: float = 1.0, pitch_variation: float = 0.0, cooldown: float = 0.0) -> void:
	var runtime := _runtime()
	if is_instance_valid(runtime):
		runtime._play_one_shot(sound_id, volume_db, pitch, pitch_variation, cooldown)


static func start_loop(channel: StringName, sound_id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var runtime := _runtime()
	if is_instance_valid(runtime):
		runtime._start_audio_loop(channel, sound_id, volume_db, pitch)


static func stop_loop(channel: StringName) -> void:
	var runtime := _runtime()
	if is_instance_valid(runtime):
		runtime._stop_audio_loop(channel)


static func _runtime() -> GameSFX:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameSFXRuntime") as GameSFX


func _play_one_shot(sound_id: StringName, volume_db: float = 0.0, pitch: float = 1.0, pitch_variation: float = 0.0, cooldown: float = 0.0) -> void:
	if _silent or not SOUNDS.has(sound_id):
		return
	var now := Time.get_ticks_msec()
	var cooldown_key := String(sound_id)
	if now < int(_cooldown_until.get(cooldown_key, 0)):
		return
	if cooldown > 0.0:
		_cooldown_until[cooldown_key] = now + int(cooldown * 1000.0)
	var player := _available_player()
	if player == null:
		return
	player.stream = SOUNDS[sound_id]
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.05, pitch + _rng.randf_range(-pitch_variation, pitch_variation))
	player.play()


func _start_audio_loop(channel: StringName, sound_id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _silent or not SOUNDS.has(sound_id):
		return
	_stop_audio_loop(channel)
	var player := AudioStreamPlayer.new()
	player.name = "Loop_%s" % channel
	player.bus = &"SFX"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	var stream: AudioStream = SOUNDS[sound_id].duplicate()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	_loops[channel] = player
	player.play()


func _stop_audio_loop(channel: StringName) -> void:
	var player := _loops.get(channel) as AudioStreamPlayer
	if not is_instance_valid(player):
		_loops.erase(channel)
		return
	player.stop()
	# Detach the stream immediately so an already-buffered loop cannot remain
	# audible for another mix frame after its owning animation has completed.
	player.stream = null
	_loops.erase(channel)
	player.queue_free()


func _available_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
	return _players[0] if not _players.is_empty() else null


func _register_existing_buttons() -> void:
	_register_buttons_below(get_tree().root)


func _register_buttons_below(node: Node) -> void:
	if node is BaseButton:
		_register_button(node as BaseButton)
	for child: Node in node.get_children():
		_register_buttons_below(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		call_deferred(&"_register_button", node as BaseButton)


func _register_button(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta(BUTTON_META):
		return
	button.set_meta(BUTTON_META, true)
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	button.focus_entered.connect(_on_button_hovered.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_hovered(button: BaseButton) -> void:
	if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
		_play_one_shot(&"button_hover", -14.0, 1.0, 0.025, 0.045)


func _on_button_pressed(button: BaseButton) -> void:
	if (
		is_instance_valid(button)
		and not button.disabled
		and not bool(button.get_meta(BUTTON_CONFIRM_SUPPRESS_META, false))
	):
		_play_one_shot(&"ui_confirm", -10.0, 1.0, 0.02, 0.035)
