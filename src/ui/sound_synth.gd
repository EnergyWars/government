class_name SoundSynth
extends RefCounted

const MIX_RATE := 22050
const PEAK := 0.85
const RELEASE := 0.012
const DEFAULT_ATTACK := 0.004
const NOISE_SEED := 7
const SINE := "sine"
const TRIANGLE := "triangle"
const SQUARE := "square"
const NOISE := "noise"


static func midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


static func length_of(notes: Array) -> float:
	var length := 0.0
	for note: Dictionary in notes:
		length = maxf(length, float(note.get("at", 0.0)) + float(note.get("len", 0.0)))
	return length


static func render(notes: Array, rate: int = MIX_RATE) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(ceilf(length_of(notes) * rate)))
	samples.fill(0.0)
	var noise := RandomNumberGenerator.new()
	noise.seed = NOISE_SEED
	for note: Dictionary in notes:
		var start := int(float(note.get("at", 0.0)) * rate)
		var voice := render_note(note, rate, noise)
		for i in mini(voice.size(), samples.size() - start):
			samples[start + i] += voice[i]
	return normalize(samples)


static func render_note(note: Dictionary, rate: int, noise: RandomNumberGenerator) -> PackedFloat32Array:
	var voice := PackedFloat32Array()
	var count := int(float(note.get("len", 0.0)) * rate)
	if count <= 0:
		return voice
	voice.resize(count)
	var length := float(count) / rate
	var wave := str(note.get("wave", SINE))
	var volume := float(note.get("vol", 1.0))
	var attack := maxf(float(note.get("attack", DEFAULT_ATTACK)), 1.0 / rate)
	var decay := float(note.get("decay", 0.0))
	var from_freq := float(note.get("freq", 440.0))
	var to_freq := float(note.get("to", from_freq))
	var smooth := clampf(float(note.get("smooth", 1.0)), 0.001, 1.0)
	var phase := 0.0
	var noise_value := 0.0
	for i in count:
		var t := float(i) / rate
		var progress := t / length
		var freq := lerpf(from_freq, to_freq, progress)
		phase = fposmod(phase + freq / rate, 1.0)
		var value := 0.0
		match wave:
			TRIANGLE:
				value = 1.0 - 4.0 * absf(phase - 0.5)
			SQUARE:
				value = 1.0 if phase < 0.5 else -1.0
			NOISE:
				noise_value += smooth * (noise.randf_range(-1.0, 1.0) - noise_value)
				value = noise_value
			_:
				value = sin(TAU * phase)
		voice[i] = value * volume * envelope(t, length, attack, decay)
	return voice


static func envelope(t: float, length: float, attack: float, decay: float) -> float:
	if t < 0.0 or t >= length:
		return 0.0
	var level := minf(t / attack, 1.0) if attack > 0.0 else 1.0
	level *= exp(-decay * maxf(t - attack, 0.0))
	var left := length - t
	if left < RELEASE:
		level *= left / RELEASE
	return level


static func normalize(samples: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0
	for value in samples:
		peak = maxf(peak, absf(value))
	if peak <= 0.0:
		return samples
	var factor := PEAK / peak
	for i in samples.size():
		samples[i] *= factor
	return samples


static func to_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	return bytes


static func to_stream(samples: PackedFloat32Array, rate: int = MIX_RATE) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = to_pcm16(samples)
	return stream
