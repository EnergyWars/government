extends GutTest

const TEST_SETTINGS := "user://test_sound_settings.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(TEST_SETTINGS)


func _player(sound: bool = true, haptics: bool = true) -> SfxPlayer:
	var settings := AppSettings.new(TEST_SETTINGS)
	settings.sound = sound
	settings.haptics = haptics
	var player := SfxPlayer.new().setup(settings)
	add_child_autofree(player)
	return player


func _peak(samples: PackedFloat32Array) -> float:
	var peak := 0.0
	for value in samples:
		peak = maxf(peak, absf(value))
	return peak


func test_midi_matches_concert_pitch() -> void:
	assert_almost_eq(SoundSynth.midi(69.0), 440.0, 0.001)
	assert_almost_eq(SoundSynth.midi(81.0), 880.0, 0.001)
	assert_almost_eq(SoundSynth.midi(60.0), 261.63, 0.01)


func test_length_covers_latest_note() -> void:
	assert_eq(SoundSynth.length_of([]), 0.0)
	assert_almost_eq(SoundSynth.length_of([{"at": 0.1, "len": 0.2}, {"at": 0.0, "len": 0.25}]), 0.3, 0.0001)


func test_render_produces_normalized_audio_for_every_wave() -> void:
	for wave in [SoundSynth.SINE, SoundSynth.TRIANGLE, SoundSynth.SQUARE, SoundSynth.NOISE]:
		var samples := SoundSynth.render([{"at": 0.0, "len": 0.1, "freq": 440.0, "wave": wave, "decay": 5.0}])
		assert_eq(samples.size(), int(ceilf(0.1 * SoundSynth.MIX_RATE)), wave)
		assert_almost_eq(_peak(samples), SoundSynth.PEAK, 0.001, wave)
		assert_almost_eq(samples[samples.size() - 1], 0.0, 0.05, wave)


func test_render_of_silence_stays_silent() -> void:
	var samples := SoundSynth.render([{"at": 0.0, "len": 0.05, "vol": 0.0}])
	assert_eq(_peak(samples), 0.0)
	assert_eq(SoundSynth.render([]).size(), 0)
	assert_eq(SoundSynth.render([{"at": 0.0, "len": 0.0}]).size(), 0)


func test_render_mixes_notes_at_their_offsets() -> void:
	var samples := SoundSynth.render([{"at": 0.0, "len": 0.05, "freq": 500.0}, {"at": 0.1, "len": 0.05, "freq": 500.0}])
	var gap := int(0.075 * SoundSynth.MIX_RATE)
	assert_eq(samples[gap], 0.0)
	assert_gt(_peak(samples.slice(int(0.1 * SoundSynth.MIX_RATE))), 0.1)


func test_noise_is_deterministic() -> void:
	var note := [{"at": 0.0, "len": 0.05, "wave": SoundSynth.NOISE, "smooth": 0.3}]
	assert_eq(SoundSynth.render(note), SoundSynth.render(note))


func test_frequency_slide_changes_waveform() -> void:
	var steady := SoundSynth.render([{"at": 0.0, "len": 0.1, "freq": 400.0}])
	var slide := SoundSynth.render([{"at": 0.0, "len": 0.1, "freq": 400.0, "to": 1200.0}])
	assert_ne(steady, slide)


func test_envelope_attack_decay_and_release() -> void:
	assert_eq(SoundSynth.envelope(-0.1, 1.0, 0.1, 0.0), 0.0)
	assert_eq(SoundSynth.envelope(1.0, 1.0, 0.1, 0.0), 0.0)
	assert_almost_eq(SoundSynth.envelope(0.05, 1.0, 0.1, 0.0), 0.5, 0.001)
	assert_almost_eq(SoundSynth.envelope(0.5, 1.0, 0.1, 0.0), 1.0, 0.001)
	assert_almost_eq(SoundSynth.envelope(0.6, 1.0, 0.1, 2.0), exp(-1.0), 0.001)
	assert_lt(SoundSynth.envelope(1.0 - SoundSynth.RELEASE * 0.5, 1.0, 0.1, 0.0), 0.6)
	assert_almost_eq(SoundSynth.envelope(0.5, 1.0, 0.0, 0.0), 1.0, 0.001)


func test_normalize_scales_to_peak_and_keeps_silence() -> void:
	var loud := SoundSynth.normalize(PackedFloat32Array([0.0, 2.0, -4.0]))
	assert_almost_eq(loud[2], -SoundSynth.PEAK, 0.0001)
	assert_almost_eq(loud[1], SoundSynth.PEAK * 0.5, 0.0001)
	assert_eq(SoundSynth.normalize(PackedFloat32Array([0.0, 0.0])), PackedFloat32Array([0.0, 0.0]))


func test_pcm16_encoding_clamps() -> void:
	var bytes := SoundSynth.to_pcm16(PackedFloat32Array([0.0, 1.0, -1.0, 2.0]))
	assert_eq(bytes.size(), 8)
	assert_eq(bytes.decode_s16(0), 0)
	assert_eq(bytes.decode_s16(2), 32767)
	assert_eq(bytes.decode_s16(4), -32767)
	assert_eq(bytes.decode_s16(6), 32767)


func test_stream_is_mono_16_bit() -> void:
	var stream := SoundSynth.to_stream(PackedFloat32Array([0.0, 0.5]))
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(stream.mix_rate, SoundSynth.MIX_RATE)
	assert_false(stream.stereo)
	assert_eq(stream.data.size(), 4)


func test_every_bank_sound_renders_short_and_audible() -> void:
	assert_eq(SoundBank.ids().size(), SoundBank.SOUNDS.size())
	for id in SoundBank.ids():
		var samples := SoundBank.samples(id)
		assert_gt(samples.size(), 0, id)
		assert_lt(samples.size(), SoundSynth.MIX_RATE * 2, id)
		assert_almost_eq(_peak(samples), SoundSynth.PEAK, 0.001, id)
		assert_lt(SoundBank.volume_db(id), 0.0, id)
		assert_gt(SoundBank.gap(id), 0.0, id)


func test_bank_handles_unknown_sounds() -> void:
	var bank := SoundBank.new()
	assert_false(SoundBank.has("missing"))
	assert_null(bank.stream("missing"))
	assert_eq(SoundBank.samples("missing").size(), 0)
	assert_eq(SoundBank.volume_db("missing"), 0.0)
	assert_eq(SoundBank.gap("missing"), SoundBank.DEFAULT_GAP)


func test_bank_caches_streams() -> void:
	var bank := SoundBank.new()
	assert_false(bank.is_cached(SoundBank.POP))
	var stream := bank.stream(SoundBank.POP)
	assert_not_null(stream)
	assert_true(bank.is_cached(SoundBank.POP))
	assert_same(bank.stream(SoundBank.POP), stream)


func test_player_creates_voice_pool() -> void:
	var player := _player()
	assert_eq(player._players.size(), SfxPlayer.VOICES)


func test_player_plays_and_throttles_per_sound() -> void:
	var player := _player()
	assert_true(player.play(SoundBank.COIN, 1.5))
	var voice: AudioStreamPlayer = player._players[0]
	assert_not_null(voice.stream)
	assert_almost_eq(voice.pitch_scale, 1.5, 0.001)
	assert_eq(voice.volume_db, SoundBank.volume_db(SoundBank.COIN))
	assert_false(player.play(SoundBank.COIN))
	assert_true(player.play(SoundBank.POP))
	player.clock += SoundBank.gap(SoundBank.COIN)
	assert_true(player.play(SoundBank.COIN))


func test_player_clamps_pitch_and_rotates_voices() -> void:
	var player := _player()
	for index in SfxPlayer.VOICES + 1:
		player.clock += 1.0
		assert_true(player.play(SoundBank.POP, 10.0))
	assert_eq(player._cursor, 1)
	assert_almost_eq(player._players[0].pitch_scale, SfxPlayer.MAX_PITCH, 0.001)


func test_player_respects_sound_setting() -> void:
	var player := _player(false)
	assert_false(player.is_enabled())
	assert_false(player.play(SoundBank.POP))
	player.settings.sound = true
	assert_true(player.play(SoundBank.POP))
	assert_false(player.play("missing"))


func test_player_without_settings_is_enabled() -> void:
	var player := SfxPlayer.new()
	add_child_autofree(player)
	assert_true(player.is_enabled())
	assert_true(player.vibrate(1))


func test_player_respects_haptics_setting() -> void:
	assert_false(_player(true, false).vibrate(10))
	assert_true(_player(true, true).vibrate(10))


func test_player_warms_up_one_sound_per_frame() -> void:
	var player := _player()
	var queued := player._warm_queue.size()
	assert_eq(queued, SoundBank.ids().size())
	player._process(0.016)
	assert_eq(player._warm_queue.size(), queued - 1)
	assert_almost_eq(player.clock, 0.016, 0.0001)


func test_buttons_click_when_pressed() -> void:
	var player := _player()
	var button := Button.new()
	add_child_autofree(button)
	assert_true(button.pressed.is_connected(player._on_button_pressed))
	button.pressed.emit()
	assert_true(player._last_played.has(SoundBank.CLICK))
	player.watch_button(button)
	assert_eq(button.pressed.get_connections().size(), 1)


func test_settings_persist_sound_and_haptics() -> void:
	var settings := AppSettings.new(TEST_SETTINGS)
	assert_true(settings.sound)
	assert_true(settings.haptics)
	settings.set_sound(false)
	settings.set_haptics(false)
	var loaded := AppSettings.new(TEST_SETTINGS).load_settings()
	assert_false(loaded.sound)
	assert_false(loaded.haptics)
	settings.set_sound(true)
	assert_true(AppSettings.new(TEST_SETTINGS).load_settings().sound)


func test_settings_ignore_invalid_feedback_values() -> void:
	var config := ConfigFile.new()
	config.set_value("feedback", "sound", "loud")
	config.set_value("feedback", "haptics", 3)
	config.save(TEST_SETTINGS)
	var loaded := AppSettings.new(TEST_SETTINGS).load_settings()
	assert_true(loaded.sound)
	assert_true(loaded.haptics)
