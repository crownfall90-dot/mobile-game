class_name Home
extends RefCounted
## A single ordered catalog ties repairs to levels. Profile owns persistence.

const TASKS := [
	{"id":"tv", "name":"Телевизор", "title":"Первый лучик радости", "text":"Пусть у дочки снова будут любимые мультики.", "level":"home_01"},
	{"id":"light", "name":"Свет", "title":"Тёплый свет", "text":"По вечерам дома больше не будет темно.", "level":"home_02"},
	{"id":"window", "name":"Окно", "title":"Больше никаких сквозняков", "text":"Поможем семье сохранить тепло.", "level":"home_03"},
	{"id":"bed", "name":"Кровать", "title":"Спокойной ночи", "text":"Мягкая постель для маленьких снов.", "level":"home_04"},
	{"id":"sofa", "name":"Диван", "title":"Рядом с мамой", "text":"Уютный уголок для сказок и объятий.", "level":"home_05"},
	{"id":"kitchen", "name":"Кухня", "title":"Завтрак дома", "text":"Чистая кухня и горячий ужин для двоих.", "level":"home_06"},
	{"id":"bath", "name":"Ванна", "title":"Тёплая вода", "text":"Починим ванну и уберём ржавчину.", "level":"home_07"},
	{"id":"toilet", "name":"Санузел", "title":"Забота каждый день", "text":"В маленьком санузле всё должно работать.", "level":"home_08"},
	{"id":"walls", "name":"Стены", "title":"Цвет нового начала", "text":"Светлые стены изменят всю квартиру.", "level":"home_09"},
	{"id":"floor", "name":"Пол", "title":"Наш счастливый дом", "text":"Последний штрих: тёплый пол и мягкий ковёр.", "level":"home_10"},
	{"id":"house_door", "slot":"tv", "area":"house", "name":"Входная дверь", "title":"Снова в безопасности", "text":"Починим дверь после ограбления.", "level":"house_01"},
	{"id":"house_light", "slot":"light", "area":"house", "name":"Свет в доме", "title":"Тьма отступает", "text":"Вернём свет в наш новый дом.", "level":"house_02"},
	{"id":"house_kitchen", "slot":"kitchen", "area":"house", "name":"Камин и кухня", "title":"Тепло большого дома", "text":"Починим очаг и снова соберёмся за ужином.", "level":"house_03"},
	{"id":"house_sofa", "slot":"sofa", "area":"house", "name":"Гостиная", "title":"Место для всей семьи", "text":"Восстановим просторную гостиную.", "level":"house_04"},
	{"id":"house_bed", "slot":"bed", "area":"house", "name":"Спальня", "title":"Новые мечты", "text":"У дочки будет собственный уютный уголок.", "level":"house_05"},
	{"id":"house_bath", "slot":"bath", "area":"house", "name":"Ванная", "title":"Дом снова наш", "text":"Последний ремонт в доме. Дальше — во двор!", "level":"house_06"},
	{"id":"yard_gate", "slot":"gate", "area":"yard", "name":"Ворота", "title":"Добро пожаловать", "text":"Восстановим ворота нашего участка.", "level":"yard_01"},
	{"id":"yard_path", "slot":"path", "area":"yard", "name":"Дорожка", "title":"Дорога домой", "text":"Уложим дорожку от ворот к крыльцу.", "level":"yard_02"},
	{"id":"yard_garden", "slot":"garden", "area":"yard", "name":"Сад", "title":"Пусть всё расцветает", "text":"Маленькая дочь мечтает о своём саде.", "level":"yard_03"},
	{"id":"yard_bench", "slot":"bench", "area":"yard", "name":"Зона отдыха", "title":"Вместе под открытым небом", "text":"Место для чая, сказок и счастливых вечеров.", "level":"yard_04"},
]

const SHOP := [
	{"id":"vita_plant", "name":"Зелёный друг", "text":"Растение для дома", "price":120},
	{"id":"vita_teddy", "name":"Мишка для дочки", "text":"Любимая игрушка рядом с кроватью", "price":180},
	{"id":"vita_clothes", "name":"Семейное обновление", "text":"Новые наряды маме и дочке", "price":260},
	{"id":"vita_picture", "name":"Наши счастливые дни", "text":"Семейная картина на стене", "price":220},
]


static func completed() -> int:
	var n := 0
	for task in TASKS:
		if not Profile.flag("home." + task.id):
			break
		n += 1
	return n


static func next_task() -> Dictionary:
	var n := completed()
	return TASKS[n] if n < TASKS.size() else {}


static func task_for_level(id: String) -> Dictionary:
	for task in TASKS:
		if task.level == id:
			return task
	return {}


static func finish(level_id: String, won: bool) -> String:
	var task := next_task()
	if not won or task.is_empty() or task.level != level_id:
		return ""
	Profile.set_flag("home." + task.id)
	# Persist before the result animation; closing the app cannot lose a repair.
	Profile.flush()
	return task.id


static func stage() -> int:
	if Profile.owns("vita_clothes"):
		return 3
	return 0 if completed() < 2 else (1 if completed() < 6 else 2)


static func slot(task: Dictionary) -> String:
	return str(task.get("slot",task.get("id","")))


static func area(task: Dictionary) -> String:
	return str(task.get("area","flat"))


static func buy(id: String) -> bool:
	for item in SHOP:
		if item.id == id and not Profile.owns(id) and Profile.spend_coins(item.price,"decor"):
			Profile.grant(id)
			Profile.flush()
			return true
	return false
