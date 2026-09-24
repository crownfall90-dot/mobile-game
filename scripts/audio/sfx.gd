extends Node
## Автозагрузка "Sfx": заглушка. Синтез звуков и вибрацию пишет поток Art/Audio.


## Вызывать каждый кадр загрузки, пока не вернёт true.
func prepare(_budget_ms: int) -> bool:
	return true


func play(_id: StringName, _semitones := 0.0, _volume_db := 0.0) -> void:
	pass


func haptic(_ms: int) -> void:
	pass


func set_music(_on: bool) -> void:
	pass
