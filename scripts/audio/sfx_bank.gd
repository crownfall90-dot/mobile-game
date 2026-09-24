extends RefCounted
## Таблица звуков DESIGN §12: рецепты, громкость, троттлинг, «лесенки».
## Рецепт — список слоёв [вид, аргументы Synth без буфера...]. steps() режет слои на куски
## по CHUNK сэмплов и добавляет выравнивание пика, а Sfx.prepare() выполняет эти шаги по
## одному, чтобы кадр загрузки не превышал бюджет. «Треугольник» — ring() с h3 = 1/9.

const Synth := preload("res://scripts/audio/synth.gd")
const TONE := 0
const RING := 1
const NOISE := 2
const DC := 3
const PEAK := 4
const GAIN := 5
const TRI := 1.0 / 9.0
const CHUNK := 2048              # сэмплов слоя на шаг: здесь ~0,5 мс, на слабом телефоне ~2 мс
const PEAK_DB := -3.0
## Необязательные аргументы Synth по видам слоя (после обязательных), чтобы дописать from/to/st.
const REQUIRED := {TONE: 5, RING: 4, NOISE: 3}
const DEFAULTS := {
	TONE: [0.001, 0.0, 0.0, 0.0, Synth.RELEASE],
	RING: [0.0, 0.0015],
	NOISE: [0.0, 0.0, 0.001, 0.0, 0.0, 0.0, 1],
}

## id -> [длина, с; громкость, дБ; троттлинг, мс; лесенка — высоту задаёт вызов, без случайной]
const TABLE := {
	&"ui_tap": [0.05, -7.0, 40, false],
	&"ui_pop": [0.11, -5.5, 0, false],
	&"pin": [0.18, -1.0, 0, true],
	&"steam": [0.40, -6.0, 90, false],
	&"stone_tock": [0.06, 0.0, 40, true],
	&"fizz": [0.27, -7.0, 90, false],
	&"slime_pop": [0.21, 0.0, 60, false],
	&"magma_hiss": [0.55, -2.5, 0, false],
	&"grate_hit": [0.08, -3.5, 60, false],
	&"grate_break": [0.64, -1.0, 0, false],
	&"transmute": [0.46, -6.0, 70, true],
	&"coin": [0.15, -8.5, 35, true],
	&"gem": [0.32, -4.5, 35, true],
	&"relic": [0.60, -2.0, 0, false],
	&"star1": [0.45, -3.0, 0, false],
	&"star2": [0.45, -3.0, 0, false],
	&"star3": [0.45, -3.0, 0, false],
	&"win": [1.10, 0.0, 0, false],
	&"lose": [0.62, -0.5, 0, false],
	&"eureka": [0.55, -6.0, 0, false],
	&"chest": [0.95, -2.5, 0, false],
	&"purchase": [0.48, -0.5, 0, false],
	&"restore": [0.28, 0.0, 0, false],
}
const STAR_HZ := {&"star1": 880.0, &"star2": 1175.0, &"star3": 1568.0}
const RELIC_HZ: Array[float] = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0]   # C6 D6 E6 G6 A6
const WIN_HZ: Array[float] = [523.25, 659.26, 783.99, 1046.5]            # C5 E5 G5 C6


## Звук целиком — для play() до конца prepare(). Те же шаги, поэтому звук тот же.
static func render(id: StringName) -> AudioStreamWAV:
	if not TABLE.has(id):
		return null
	var b := Synth.buffer(TABLE[id][0])
	var st := PackedFloat64Array()
	for step: Array in steps(id):
		run(b, step, st)
	return Synth.encode(b)


## Шаги синтеза: куски слоёв [вид, аргументы, from, to], затем хвост и пик по кускам.
static func steps(id: StringName) -> Array:
	var size := int(ceil(float(TABLE[id][0]) * Synth.RATE))
	var out := []
	for layer: Array in layers(id):
		var kind: int = layer[0]
		if kind == DC:
			out.append([DC, [], 0, size])
			continue
		var args := layer.slice(1)
		var defaults: Array = DEFAULTS[kind]
		args.append_array(defaults.slice(args.size() - int(REQUIRED[kind])))
		var i0 := int(float(args[0]) * Synth.RATE)
		var dur: float = 4.6 * float(args[3]) if kind == RING else float(args[1])
		var n := mini(int(dur * Synth.RATE), size - i0)
		for from in range(0, n, CHUNK):
			out.append([kind, args, from, mini(from + CHUNK, n)])
	for kind: int in [PEAK, GAIN]:
		for from in range(0, size, CHUNK * 4):
			out.append([kind, [], from, mini(from + CHUNK * 4, size)])
	return out


## Один шаг. st переносит состояние слоя от куска к куску, а потом — найденный пик.
static func run(b: PackedFloat32Array, step: Array, st: PackedFloat64Array) -> void:
	var from: int = step[2]
	var to: int = step[3]
	var args: Array = [b] + step[1] + [from, to, st]
	match step[0]:
		TONE:
			Synth.tone.callv(args)
		RING:
			Synth.ring.callv(args)
		NOISE:
			Synth.noise.callv(args)
		DC:
			Synth.dc_block(b)
		PEAK:
			if from == 0:
				Synth.fade_end(b)
				st.resize(1)
				st[0] = 0.0
			st[0] = maxf(st[0], Synth.peak(b, from, to))
		GAIN:
			Synth.gain(b, db_to_linear(PEAK_DB) / maxf(st[0], 1e-9), from, to)


## tone: at, dur, f0, f1, amp, atk, tau, vib_hz, vib
## ring: at, f, amp, tau, h3
## noise: at, dur, amp, lo, hi, atk, tau, am_hz, am, seed
static func layers(id: StringName) -> Array:
	match id:
		&"ui_tap":
			return [
				[TONE, 0.0, 0.045, 880.0, 620.0, 1.0, 0.001, 0.012],
				[TONE, 0.0, 0.03, 1760.0, 1320.0, 0.2, 0.001, 0.006],
				[NOISE, 0.0, 0.008, 0.25, 2000.0, 8000.0, 0.0003, 0.002, 0.0, 0.0, 2],
			]
		&"ui_pop":
			return [
				[TONE, 0.0, 0.11, 300.0, 650.0, 1.0, 0.006, 0.05],
				[TONE, 0.0, 0.1, 600.0, 1300.0, 0.2, 0.006, 0.03],
			]
		&"pin":
			return [
				[NOISE, 0.0, 0.04, 1.4, 1800.0, 6000.0, 0.0005, 0.012, 0.0, 0.0, 3],
				[TONE, 0.004, 0.15, 600.0, 1730.0, 1.0, 0.002, 0.05],
				[TONE, 0.004, 0.12, 1656.0, 3864.0, 0.25, 0.001, 0.03],
			]
		&"steam":
			return [
				[NOISE, 0.0, 0.4, 1.0, 1800.0, 7000.0, 0.004, 0.1, 0.0, 0.0, 5],
				[NOISE, 0.0, 0.3, 0.6, 400.0, 1500.0, 0.008, 0.07, 0.0, 0.0, 6],
			]
		&"stone_tock":
			return [
				[TONE, 0.0, 0.05, 115.0, 85.0, 0.45, 0.0005, 0.014],
				[RING, 0.0, 700.0, 0.6, 0.012],
				[RING, 0.0, 2000.0, 0.45, 0.004],
				[NOISE, 0.0, 0.005, 0.4, 1500.0, 5000.0, 0.0002, 0.0015, 0.0, 0.0, 7],
				[DC],
			]
		&"fizz":
			return [
				[NOISE, 0.0, 0.26, 1.0, 2000.0, 6000.0, 0.005, 0.15, 30.0, 1.0, 8],
				[NOISE, 0.02, 0.22, 0.5, 3000.0, 8000.0, 0.004, 0.1, 47.0, 1.0, 9],
			]
		&"slime_pop":
			return [
				[TONE, 0.0, 0.2, 500.0, 110.0, 1.0, 0.001, 0.09, 12.0, 0.06],
				[TONE, 0.0, 0.16, 1000.0, 260.0, 0.35, 0.001, 0.05, 12.0, 0.06],
				[NOISE, 0.0, 0.04, 1.2, 300.0, 2500.0, 0.0005, 0.012, 0.0, 0.0, 10],
			]
		&"magma_hiss":
			return [
				[NOISE, 0.0, 0.52, 1.0, 1500.0, 7000.0, 0.008, 0.16, 0.0, 0.0, 11],
				[TONE, 0.0, 0.52, 72.0, 62.0, 0.2, 0.012, 0.2],
				[TONE, 0.0, 0.48, 144.0, 124.0, 0.16, 0.012, 0.14],
			]
		&"grate_hit":
			return [
				[NOISE, 0.0, 0.06, 1.0, 2000.0, 6000.0, 0.001, 0.03, 30.0, 1.0, 12],
				[RING, 0.0, 1200.0, 0.8, 0.009],
				[RING, 0.0, 3312.0, 0.2, 0.004],
			]
		&"grate_break":
			return [
				[NOISE, 0.0, 0.02, 1.0, 1000.0, 8000.0, 0.0002, 0.005, 0.0, 0.0, 13],
				[RING, 0.0, 523.0, 1.0, 0.11],
				[RING, 0.0, 526.0, 0.4, 0.1],
				[RING, 0.0, 1410.0, 0.6, 0.08],
				[RING, 0.0, 2230.0, 0.45, 0.06],
				[NOISE, 0.12, 0.52, 2.5, 2000.0, 6000.0, 0.02, 0.15, 30.0, 1.0, 14],
			]
		&"transmute":
			return [
				[RING, 0.0, 1568.0, 1.0, 0.1],
				[RING, 0.0, 2349.0, 0.6, 0.08],
				[RING, 0.0, 4327.0, 0.15, 0.02],
				[RING, 0.08, 3136.0, 0.3, 0.035],
				[RING, 0.14, 3951.0, 0.3, 0.035],
				[RING, 0.2, 4699.0, 0.3, 0.05],
			]
		&"coin":
			return coin(0.0, 0.0, 1.0)
		&"gem":
			return coin(0.0, 0.0, 1.0) + [
				[RING, 0.05, 2637.0, 0.35, 0.09, TRI],
				[RING, 0.05, 2651.0, 0.25, 0.09],
			]
		&"relic":
			var out := []
			for k in 5:
				out.append([RING, k * 0.07, RELIC_HZ[k], 0.7, 0.12 if k == 4 else 0.08, TRI])
				out.append([RING, k * 0.07, RELIC_HZ[k] * 2.0, 0.15, 0.06])
			return out
		&"star1", &"star2", &"star3":
			var f: float = STAR_HZ[id]
			return [
				[RING, 0.0, f, 1.0, 0.09, TRI],
				[RING, 0.0, f * 2.0, 0.3, 0.15],
				[RING, 0.0, f * 2.01, 0.2, 0.15],
			]
		&"win":
			var out := []
			for k in 4:
				out.append([RING, k * 0.09, WIN_HZ[k], 0.7, 0.1, TRI])
			# аккорд «бряцанием»: струны с разносом 15 мс
			for k in 4:
				out.append([RING, 0.36 + k * 0.015, WIN_HZ[k], 0.32, 0.25, TRI])
			out.append([RING, 0.42, 2093.0, 0.1, 0.2])
			return out
		&"lose":
			# «приглушённый квадрат»: основной тон и тихая 3-я гармоника
			return [
				[TONE, 0.0, 0.22, 392.0, 392.0, 0.6, 0.004, 0.4],
				[TONE, 0.0, 0.22, 1176.0, 1176.0, 0.13, 0.004, 0.4],
				[TONE, 0.2, 0.42, 311.1, 296.0, 0.6, 0.004, 0.3, 5.0, 0.015],
				[TONE, 0.2, 0.42, 933.3, 888.0, 0.13, 0.004, 0.3, 5.0, 0.015],
			]
		&"eureka":
			return [
				[TONE, 0.0, 0.28, 600.0, 1800.0, 0.8, 0.004, 0.3],
				[TONE, 0.0, 0.28, 1800.0, 5400.0, 0.08, 0.004, 0.3],
				[RING, 0.29, 2349.0, 0.5, 0.035],
				[RING, 0.37, 3136.0, 0.5, 0.05],
			]
		&"chest":
			var out := []
			for k in 3:
				out.append([NOISE, k * 0.08, 0.035, 1.4, 600.0, 3500.0, 0.0005, 0.01, 0.0, 0.0, 20 + k])
				out.append([TONE, k * 0.08, 0.04, 260.0, 200.0, 0.5, 0.0005, 0.015])
			out.append([TONE, 0.24, 0.3, 400.0, 1600.0, 0.6, 0.004])
			out.append([TONE, 0.24, 0.3, 1200.0, 4800.0, 0.07, 0.004])
			for k in 8:
				out.append_array(coin(0.46 + k * 0.04, k, 0.55))
			return out
		&"purchase":
			var out := [
				[TONE, 0.0, 0.25, 180.0, 55.0, 1.0, 0.006, 0.08],
				[NOISE, 0.0, 0.2, 0.8, 100.0, 700.0, 0.008, 0.06, 0.0, 0.0, 30],
			]
			for k in 5:
				out.append_array(coin(0.06 + k * 0.05, k * 2, 0.6))
			return out
		&"restore":
			return [
				[NOISE, 0.0, 0.22, 1.6, 150.0, 1500.0, 0.012, 0.08, 0.0, 0.0, 31],
				[TONE, 0.16, 0.09, 440.0, 1000.0, 1.0, 0.002, 0.04],
				[TONE, 0.16, 0.09, 880.0, 2000.0, 0.2, 0.002, 0.03],
			]
	return []


## Монетка: два блипа 1320 → 1760 Гц по ~60 мс; semis поднимает оба (каскады сундука и покупки).
static func coin(at: float, semis: float, amp: float) -> Array:
	var r := pow(2.0, semis / 12.0)
	return [
		[RING, at, 1320.0 * r, 0.7 * amp, 0.025, 0.12],
		[RING, at + 0.055, 1760.0 * r, amp, 0.04, 0.1],
	]
