class_name SoundBank
extends RefCounted

const CLICK := "click"
const COIN := "coin"
const POP := "pop"
const CASH := "cash"
const CHIME := "chime"
const LEVEL_UP := "level_up"
const FANFARE := "fanfare"
const SPARKLE := "sparkle"
const WHOOSH := "whoosh"
const UNLOCK := "unlock"
const CLAIM := "claim"
const DEFAULT_GAP := 0.05

const SOUNDS := {
	CLICK: {"volume_db": -18.0, "gap": 0.03, "notes": [
		{"at": 0.0, "len": 0.035, "freq": 1900.0, "to": 1300.0, "vol": 0.6, "decay": 60.0},
	]},
	COIN: {"volume_db": -13.0, "gap": 0.05, "notes": [
		{"at": 0.0, "len": 0.06, "freq": 987.8, "wave": "square", "vol": 0.35, "decay": 6.0},
		{"at": 0.06, "len": 0.24, "freq": 1318.5, "wave": "square", "vol": 0.35, "decay": 11.0},
		{"at": 0.06, "len": 0.24, "freq": 2637.0, "vol": 0.15, "decay": 16.0},
	]},
	POP: {"volume_db": -8.0, "gap": 0.05, "notes": [
		{"at": 0.0, "len": 0.1, "freq": 380.0, "to": 1100.0, "vol": 1.0, "decay": 22.0},
		{"at": 0.0, "len": 0.06, "freq": 760.0, "to": 2200.0, "vol": 0.25, "decay": 40.0},
	]},
	CASH: {"volume_db": -9.0, "gap": 0.06, "notes": [
		{"at": 0.0, "len": 0.06, "wave": "noise", "smooth": 0.5, "vol": 0.45, "decay": 50.0},
		{"at": 0.03, "len": 0.5, "freq": 1568.0, "vol": 0.6, "decay": 7.0},
		{"at": 0.03, "len": 0.5, "freq": 2093.0, "vol": 0.45, "decay": 8.0},
		{"at": 0.03, "len": 0.25, "freq": 4327.7, "vol": 0.18, "decay": 18.0},
	]},
	CHIME: {"volume_db": -9.0, "gap": 0.2, "notes": [
		{"at": 0.0, "len": 0.5, "freq": 1046.5, "vol": 0.7, "decay": 6.0},
		{"at": 0.0, "len": 0.25, "freq": 2888.3, "vol": 0.18, "decay": 16.0},
		{"at": 0.11, "len": 0.65, "freq": 1568.0, "vol": 0.7, "decay": 5.0},
		{"at": 0.11, "len": 0.3, "freq": 4327.7, "vol": 0.14, "decay": 16.0},
	]},
	LEVEL_UP: {"volume_db": -10.0, "gap": 0.15, "notes": [
		{"at": 0.0, "len": 0.16, "freq": 523.3, "wave": "triangle", "vol": 0.6, "decay": 6.0},
		{"at": 0.07, "len": 0.16, "freq": 659.3, "wave": "triangle", "vol": 0.6, "decay": 6.0},
		{"at": 0.14, "len": 0.16, "freq": 784.0, "wave": "triangle", "vol": 0.6, "decay": 6.0},
		{"at": 0.21, "len": 0.45, "freq": 1046.5, "wave": "triangle", "vol": 0.7, "decay": 4.0},
		{"at": 0.21, "len": 0.45, "freq": 2093.0, "vol": 0.2, "decay": 7.0},
	]},
	FANFARE: {"volume_db": -8.0, "gap": 0.4, "notes": [
		{"at": 0.0, "len": 0.13, "freq": 392.0, "wave": "triangle", "vol": 0.6, "decay": 3.0},
		{"at": 0.12, "len": 0.13, "freq": 523.3, "wave": "triangle", "vol": 0.6, "decay": 3.0},
		{"at": 0.24, "len": 0.13, "freq": 659.3, "wave": "triangle", "vol": 0.6, "decay": 3.0},
		{"at": 0.36, "len": 0.8, "freq": 784.0, "wave": "triangle", "vol": 0.7, "attack": 0.01, "decay": 2.2},
		{"at": 0.36, "len": 0.8, "freq": 523.3, "wave": "triangle", "vol": 0.4, "attack": 0.01, "decay": 2.2},
		{"at": 0.36, "len": 0.8, "freq": 659.3, "wave": "triangle", "vol": 0.35, "attack": 0.01, "decay": 2.2},
		{"at": 0.36, "len": 0.8, "freq": 1568.0, "vol": 0.15, "attack": 0.01, "decay": 4.0},
		{"at": 0.36, "len": 0.5, "freq": 784.0, "wave": "square", "vol": 0.08, "attack": 0.01, "decay": 5.0},
	]},
	SPARKLE: {"volume_db": -12.0, "gap": 0.15, "notes": [
		{"at": 0.0, "len": 0.22, "freq": 2093.0, "vol": 0.45, "decay": 14.0},
		{"at": 0.05, "len": 0.22, "freq": 2637.0, "vol": 0.45, "decay": 14.0},
		{"at": 0.1, "len": 0.22, "freq": 3136.0, "vol": 0.45, "decay": 14.0},
		{"at": 0.15, "len": 0.3, "freq": 4186.0, "vol": 0.4, "decay": 12.0},
	]},
	WHOOSH: {"volume_db": -10.0, "gap": 0.2, "notes": [
		{"at": 0.0, "len": 0.45, "wave": "noise", "smooth": 0.12, "vol": 0.8, "attack": 0.18, "decay": 3.0},
		{"at": 0.0, "len": 0.45, "freq": 220.0, "to": 880.0, "vol": 0.3, "attack": 0.15, "decay": 3.0},
	]},
	UNLOCK: {"volume_db": -8.0, "gap": 0.4, "notes": [
		{"at": 0.0, "len": 0.32, "freq": 523.3, "to": 2093.0, "vol": 0.45, "attack": 0.02, "decay": 2.0},
		{"at": 0.3, "len": 0.9, "freq": 1046.5, "vol": 0.5, "decay": 3.0},
		{"at": 0.3, "len": 0.9, "freq": 1318.5, "vol": 0.45, "decay": 3.0},
		{"at": 0.3, "len": 0.9, "freq": 1568.0, "vol": 0.4, "decay": 3.0},
		{"at": 0.38, "len": 0.25, "freq": 3136.0, "vol": 0.25, "decay": 12.0},
		{"at": 0.46, "len": 0.25, "freq": 4186.0, "vol": 0.2, "decay": 12.0},
	]},
	CLAIM: {"volume_db": -10.0, "gap": 0.3, "notes": [
		{"at": 0.0, "len": 0.12, "freq": 1318.5, "wave": "triangle", "vol": 0.5, "decay": 14.0},
		{"at": 0.06, "len": 0.12, "freq": 1568.0, "wave": "triangle", "vol": 0.5, "decay": 14.0},
		{"at": 0.12, "len": 0.12, "freq": 1760.0, "wave": "triangle", "vol": 0.5, "decay": 14.0},
		{"at": 0.18, "len": 0.12, "freq": 2093.0, "wave": "triangle", "vol": 0.5, "decay": 14.0},
		{"at": 0.24, "len": 0.45, "freq": 2637.0, "wave": "triangle", "vol": 0.6, "decay": 6.0},
		{"at": 0.24, "len": 0.45, "freq": 5274.0, "vol": 0.12, "decay": 10.0},
	]},
}

var _streams := {}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in SOUNDS:
		result.append(id)
	return result


static func has(id: String) -> bool:
	return SOUNDS.has(id)


static func volume_db(id: String) -> float:
	return float(SOUNDS.get(id, {}).get("volume_db", 0.0))


static func gap(id: String) -> float:
	return float(SOUNDS.get(id, {}).get("gap", DEFAULT_GAP))


static func samples(id: String) -> PackedFloat32Array:
	return SoundSynth.render(SOUNDS[id].notes) if has(id) else PackedFloat32Array()


func is_cached(id: String) -> bool:
	return _streams.has(id)


func stream(id: String) -> AudioStreamWAV:
	if not has(id):
		return null
	if not _streams.has(id):
		_streams[id] = SoundSynth.to_stream(samples(id))
	return _streams[id]
