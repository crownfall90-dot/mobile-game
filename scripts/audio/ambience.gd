extends RefCounted
## Фоновые звуки-петли, синтез кодом: "storm" — дождь (шипение и капли) с порывами ветра,
## "wind" — холодный ветер-сквозняк. Петля 6 с, конец плавно наложен на начало — без щелчка.
## Считается в фоновом потоке (Sfx.ambience), отдаёт 16-битный PCM.

const Synth := preload("res://scripts/audio/synth.gd")
const LOOP := 6.0
const BLEND := 0.8


static func render(kind: StringName) -> PackedByteArray:
	var b := Synth.buffer(LOOP + BLEND)
	var dur := LOOP + BLEND
	match kind:
		&"storm":
			Synth.noise(b, 0.0, dur, 0.5, 700.0, 5200.0, 0.3, 0.0, 0.0, 0.0, 3)
			Synth.noise(b, 0.0, dur, 0.9, 50.0, 420.0, 0.5, 0.0, 1.0 / LOOP, 0.75, 5)
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for i in 70:
				Synth.ring(b, rng.randf() * LOOP, rng.randf_range(1700.0, 3300.0), rng.randf_range(0.03, 0.09), 0.012)
		&"wind":
			Synth.noise(b, 0.0, dur, 1.0, 40.0, 380.0, 0.5, 0.0, 1.0 / LOOP, 0.85, 7)
			Synth.noise(b, 0.0, dur, 0.25, 600.0, 1400.0, 0.5, 0.0, 2.0 / LOOP, 0.9, 9)
		_:
			return PackedByteArray()
	var n := int(LOOP * Synth.RATE)
	var f := int(BLEND * Synth.RATE)
	for i in f:
		var k := float(i) / f
		b[i] = b[i] * k + b[n + i] * (1.0 - k)
	b.resize(n)
	var g := 0.6 / maxf(0.001, Synth.peak(b))
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		pcm.encode_s16(i * 2, int(clampf(b[i] * g, -1.0, 1.0) * 32767.0))
	return pcm
