extends RefCounted
## Синтез коротких звуков (DESIGN §12): осцилляторы, шум, фильтры, огибающие.
## Слои складываются в моно-буфер PackedFloat32Array 22 050 Гц;
## to_stream() выравнивает пик и отдаёт 16-битный AudioStreamWAV.
## Всё статическое и не трогает сцену, поэтому годится и для рабочего потока.
##
## Огибающая везде — разность двух экспонент: мягкая атака с постоянной atk и спад
## с постоянной tau (tau = 0 — звук держится). Так в горячем цикле нет ветвлений.
##
## Слой можно считать кусками: from/to — отрезок сэмплов слоя, st — состояние
## осцилляторов и фильтров, которое кусок оставляет следующему (куски идут по порядку).
## Результат совпадает с расчётом слоя целиком.

const RATE := 22050
const RELEASE := 0.006     # короткий спад в конце слоя, чтобы не было щелчка
const END_FADE := 0.02     # и такой же в самом конце буфера


static func buffer(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(ceil(sec * RATE)))
	b.fill(0.0)
	return b


## Синус длиной dur с момента at; частота скользит экспоненциально f0 → f1 за весь слой.
## vib — глубина вибрато (0.05 = ±5%) с частотой vib_hz; rel — линейный спад в конце слоя.
static func tone(b: PackedFloat32Array, at: float, dur: float, f0: float, f1: float, amp: float,
		atk := 0.001, tau := 0.0, vib_hz := 0.0, vib := 0.0, rel := RELEASE,
		from := 0, to := -1, st := PackedFloat64Array()) -> void:
	var i0 := int(at * RATE)
	var n := mini(int(dur * RATE), b.size() - i0)
	if n <= 0:
		return
	var w := TAU * f0 / RATE
	var wk := pow(f1 / f0, 1.0 / maxf(1.0, dur * RATE))
	var dk := exp(-1.0 / (tau * RATE)) if tau > 0.0 else 1.0
	var ak := exp(-1.0 / (maxf(atk, 0.0001) * RATE))
	var ed := amp
	var ea := amp
	var rel_i := n - int(rel * RATE)
	var inv_rel := 1.0 / maxf(1.0, rel * RATE)
	var ph := 0.0
	if from > 0 and st.size() >= 4:
		ph = st[0]
		w = st[1]
		ed = st[2]
		ea = st[3]
	var end := n if to < 0 else mini(to, n)
	if vib > 0.0:
		var vw := TAU * vib_hz / RATE
		for i in range(from, end):
			ed *= dk
			ea *= ak
			w *= wk
			ph += w * (1.0 + vib * sin(vw * i))
			var g := ed - ea
			if i >= rel_i:
				g *= (n - i) * inv_rel
			b[i0 + i] += sin(ph) * g
	else:
		for i in range(from, end):
			ed *= dk
			ea *= ak
			w *= wk
			ph += w
			var g := ed - ea
			if i >= rel_i:
				g *= (n - i) * inv_rel
			b[i0 + i] += sin(ph) * g
	_keep(st, [ph, w, ed, ea])


## Затухающая синусоида постоянной частоты: колокол, звон, блик монетки.
## h3 — доля 3-й гармоники (1/9 — «треугольник»), она гаснет быстрее основного тона.
## Считается рекуррентно, без sin в цикле; длится до −40 дБ или до конца буфера.
static func ring(b: PackedFloat32Array, at: float, f: float, amp: float, tau: float, h3 := 0.0,
		atk := 0.0015, from := 0, to := -1, st := PackedFloat64Array()) -> void:
	var i0 := int(at * RATE)
	var n := mini(int(4.6 * tau * RATE), b.size() - i0)
	if n <= 0:
		return
	var w := TAU * f / RATE
	var r := exp(-1.0 / (tau * RATE))
	var c1 := 2.0 * r * cos(w)
	var c2 := r * r
	var y1 := 0.0
	var y2 := -amp * sin(w) / r
	var q := exp(-1.0 / (0.6 * tau * RATE))
	var d1 := 2.0 * q * cos(3.0 * w)
	var d2 := q * q
	var z1 := 0.0
	var z2 := 0.0
	if h3 > 0.0 and f * 3.0 < RATE * 0.45:
		z2 = -amp * h3 * sin(3.0 * w) / q
	if from > 0 and st.size() >= 4:
		y1 = st[0]
		y2 = st[1]
		z1 = st[2]
		z2 = st[3]
	var end := n if to < 0 else mini(to, n)
	# короткая линейная атака: без щелчка на первом сэмпле
	var m := mini(n, maxi(1, int(atk * RATE)))
	for i in range(from, mini(m, end)):
		var y := c1 * y1 - c2 * y2
		y2 = y1
		y1 = y
		var z := d1 * z1 - d2 * z2
		z2 = z1
		z1 = z
		b[i0 + i] += (y + z) * i / m
	if z1 == 0.0 and z2 == 0.0:
		for i in range(maxi(m, from), end):
			var y := c1 * y1 - c2 * y2
			y2 = y1
			y1 = y
			b[i0 + i] += y
	else:
		for i in range(maxi(m, from), end):
			var y := c1 * y1 - c2 * y2
			y2 = y1
			y1 = y
			var z := d1 * z1 - d2 * z2
			z2 = z1
			z1 = z
			b[i0 + i] += y + z
	_keep(st, [y1, y2, z1, z2])


## Шум: белый, затем полоса [lo, hi] — по два однополюсных фильтра с каждой стороны
## (0 — без среза). am — глубина модуляции синусом am_hz (1.0 = 0.5 + 0.5·sin).
static func noise(b: PackedFloat32Array, at: float, dur: float, amp: float, lo := 0.0, hi := 0.0,
		atk := 0.001, tau := 0.0, am_hz := 0.0, am := 0.0, seed := 1,
		from := 0, to := -1, st := PackedFloat64Array()) -> void:
	var i0 := int(at * RATE)
	var n := mini(int(dur * RATE), b.size() - i0)
	if n <= 0:
		return
	var ah := 1.0 - exp(-TAU * hi / RATE) if hi > 0.0 else 1.0
	var al := 1.0 - exp(-TAU * lo / RATE) if lo > 0.0 else 0.0
	var dk := exp(-1.0 / (tau * RATE)) if tau > 0.0 else 1.0
	var ak := exp(-1.0 / (maxf(atk, 0.0001) * RATE))
	var ed := amp
	var ea := amp
	var rel_i := n - int(RELEASE * RATE)
	var inv_rel := 1.0 / (RELEASE * RATE)
	var aw := TAU * am_hz / RATE
	var s := (seed * 7919 + 17) & 0x7fffffff
	var l1 := 0.0
	var l2 := 0.0
	var h1 := 0.0
	var h2 := 0.0
	if from > 0 and st.size() >= 7:
		ed = st[0]
		ea = st[1]
		s = int(st[2])
		l1 = st[3]
		l2 = st[4]
		h1 = st[5]
		h2 = st[6]
	var end := n if to < 0 else mini(to, n)
	for i in range(from, end):
		ed *= dk
		ea *= ak
		s = (s * 1103515245 + 12345) & 0x7fffffff
		l1 += ah * (float(s) * (2.0 / 2147483647.0) - 1.0 - l1)
		l2 += ah * (l1 - l2)
		h1 += al * (l2 - h1)
		var y := l2 - h1
		h2 += al * (y - h2)
		var g := ed - ea
		if am > 0.0:
			g *= 1.0 - am * (0.5 - 0.5 * sin(aw * i))
		if i >= rel_i:
			g *= (n - i) * inv_rel
		b[i0 + i] += (y - h2) * g
	_keep(st, [ed, ea, s, l1, l2, h1, h2])


## ФВЧ ~20 Гц по всему буферу: снимает постоянную составляющую коротких «бухающих» слоёв.
static func dc_block(b: PackedFloat32Array) -> void:
	var r := 1.0 - TAU * 20.0 / RATE
	var x1 := 0.0
	var y1 := 0.0
	for i in b.size():
		var x := b[i]
		y1 = x - x1 + r * y1
		x1 = x
		b[i] = y1


## Состояние слоя для следующего куска (если его просили сохранить).
static func _keep(st: PackedFloat64Array, v: Array) -> void:
	st.resize(v.size())
	for i in v.size():
		st[i] = v[i]


## Пик → peak_db, плавный хвост в конце, затем float-WAV в памяти → 16 бит силами движка.
static func to_stream(b: PackedFloat32Array, peak_db := -3.0, fade := true) -> AudioStreamWAV:
	if fade:
		fade_end(b)
	gain(b, db_to_linear(peak_db) / maxf(peak(b), 1e-9))
	return encode(b)


## Плавный хвост в конце буфера, чтобы звук не обрывался щелчком.
static func fade_end(b: PackedFloat32Array) -> void:
	var n := b.size()
	var m := mini(n, int(END_FADE * RATE))
	for k in m:
		b[n - 1 - k] *= float(k) / m


## Наибольший |x| на отрезке [from, to).
static func peak(b: PackedFloat32Array, from := 0, to := -1) -> float:
	var p := 0.0
	for i in range(from, b.size() if to < 0 else to):
		p = maxf(p, absf(b[i]))
	return p


static func gain(b: PackedFloat32Array, g: float, from := 0, to := -1) -> void:
	for i in range(from, b.size() if to < 0 else to):
		b[i] *= g


## Готовый (уже выровненный) буфер → float-WAV в памяти → 16 бит силами движка.
static func encode(b: PackedFloat32Array) -> AudioStreamWAV:
	var pcm := b.to_byte_array()
	var wav := PackedByteArray()
	wav.resize(44)
	wav.encode_u32(0, 0x46464952)    # "RIFF"
	wav.encode_u32(4, 36 + pcm.size())
	wav.encode_u32(8, 0x45564157)    # "WAVE"
	wav.encode_u32(12, 0x20746d66)   # "fmt "
	wav.encode_u32(16, 16)
	wav.encode_u16(20, 3)            # IEEE float
	wav.encode_u16(22, 1)
	wav.encode_u32(24, RATE)
	wav.encode_u32(28, RATE * 4)
	wav.encode_u16(32, 4)
	wav.encode_u16(34, 32)
	wav.encode_u32(36, 0x61746164)   # "data"
	wav.encode_u32(40, pcm.size())
	wav.append_array(pcm)
	return AudioStreamWAV.load_from_buffer(wav, {"compress/mode": 0, "edit/normalize": false,
			"edit/trim": false, "edit/loop_mode": 1, "force/max_rate": false, "force/mono": false,
			"force/8_bit": false})


## Готовый 16-битный звук из сырых PCM-байтов (кэш музыки). loop — бесшовный повтор.
static func from_pcm16(pcm: PackedByteArray, loop := false) -> AudioStreamWAV:
	var ws := AudioStreamWAV.new()
	ws.format = AudioStreamWAV.FORMAT_16_BITS
	ws.mix_rate = RATE
	ws.stereo = false
	ws.data = pcm
	if loop:
		ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ws.loop_begin = 0
		ws.loop_end = pcm.size() / 2
	return ws
