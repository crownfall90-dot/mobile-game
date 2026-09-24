extends RefCounted
## Фоновая музыка (DESIGN §12, P1): 8 тактов пентатоники до мажор, 96 BPM, 20 с по кругу.
## Мягкий синусовый пэд с медленной атакой и затухающий «арфовый» щипок (треугольник).
## Считается один раз в WorkerThreadPool и кэшируется сырым PCM; при смене музыки
## поменяй путь кэша (audio_v2), иначе у игроков останется старая.

const Synth := preload("res://scripts/audio/synth.gd")
const CACHE := "user://audio_v1/music.pcm"
const BAR := 4.0 * 60.0 / 96.0     # 2.5 с
const BARS := 8
const TAIL := 3.5                  # хвосты последнего такта заворачиваются в начало петли
const TRI := 1.0 / 9.0

## Пэд по тактам (MIDI): C, Am, Dsus, Gsus, C, Am7, D(C), G(add A) — всё из пентатоники.
const PAD := [
	[48, 55, 64], [45, 52, 60], [50, 57, 64], [43, 50, 57],
	[48, 55, 64], [45, 52, 60, 67], [50, 57, 60], [43, 50, 55, 57],
]
## Арфа: четыре восьмых арпеджио на первые две доли, мелодия на 3-ю и 4-ю доли.
const ARP := [
	[60, 67, 72, 76], [57, 64, 69, 72], [62, 69, 74, 76], [55, 62, 67, 69],
	[60, 67, 72, 76], [57, 64, 69, 72], [62, 69, 72, 74], [55, 62, 67, 74],
]
const MELODY := [
	[79, 76], [81, 79], [76, 74], [74, 69],
	[79, 76], [84, 81], [86, 84], [81, 79],
]


static func frames() -> int:
	return int(BAR * BARS * Synth.RATE)


## Кэш или свежий рендер. Тяжёлая работа: звать только из рабочего потока.
static func load_or_render() -> PackedByteArray:
	if FileAccess.file_exists(CACHE):
		var cached := FileAccess.get_file_as_bytes(CACHE)
		if cached.size() == frames() * 2:
			return cached
	var pcm := render()
	DirAccess.make_dir_recursive_absolute(CACHE.get_base_dir())
	var f := FileAccess.open(CACHE, FileAccess.WRITE)
	if f:
		f.store_buffer(pcm)
	return pcm


static func render() -> PackedByteArray:
	var n := frames()
	var b := Synth.buffer(BAR * BARS + TAIL)
	for bar in BARS:
		var t0 := bar * BAR
		for m: int in PAD[bar]:
			Synth.tone(b, t0, BAR + 0.8, hz(m), hz(m), 0.16, 0.4, 0.0, 0.0, 0.0, 0.9)
		for k in 4:
			Synth.ring(b, t0 + k * BAR / 8.0, hz(ARP[bar][k]), 0.4, 0.35, TRI)
		for k in 2:
			Synth.ring(b, t0 + (4 + 2 * k) * BAR / 8.0, hz(MELODY[bar][k]), 0.55, 0.5, TRI)
	# бесшовная петля: всё, что прозвучало после конца, доигрывает в начале
	for i in b.size() - n:
		b[i] += b[n + i]
	b.resize(n)
	return Synth.to_stream(b, -3.0, false).data


static func hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)
