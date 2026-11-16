extends RefCounted

const MAX_COUNT := 99
const ROWS: Array[Dictionary] = [
	{"id": "matcha", "name": "Матча", "price": 12, "restore": 15, "category": "drink",
		"description": "Зелёная пауза для Николы Коко. Взбодрит даже после разговора с де Муром.",
		"texture_path": "res://Assets/Assets for new version of game/tamagochi/Shop assets/Menu assets/Matcha.png"},
	{"id": "hot_chocolate", "name": "Горячий шоколад", "price": 12, "restore": 15, "category": "drink",
		"description": "Лапы греются, мысли собираются. Газету в чашку не макать.",
		"texture_path": "res://Assets/Assets for new version of game/tamagochi/Shop assets/Menu assets/Hot Chocolate.png"},
	{"id": "coffee_latte", "name": "Кофе латте", "price": 12, "restore": 15, "category": "drink",
		"description": "Молочная пенка прячет кофе лучше, чем де Мур — плохие новости.",
		"texture_path": "res://Assets/Assets for new version of game/tamagochi/Shop assets/Menu assets/Coffee Latte.png"},
	{"id": "ramyun", "name": "Рамён", "price": 24, "restore": 30, "category": "food",
		"description": "Горячая лапша после смены. Рататуй советует не есть над рукописью.",
		"texture_path": "res://Assets/Assets for new version of game/tamagochi/Shop assets/Menu assets/Ramyun.png"},
	{"id": "shin_ramyun", "name": "Острый рамён", "price": 24, "restore": 30, "category": "food",
		"description": "Рататуй обещал лёгкую остринку. Кажется, у него другие представления о лёгкости.",
		"texture_path": "res://Assets/Assets for new version of game/tamagochi/Shop assets/Menu assets/Shin Ramyun.png"},
	{"id": "fish_food", "name": "Корм для рыбки", "price": 5, "restore": 0, "category": "pet",
		"description": "Маленький ужин для самой молчаливой соседки Николы Коко.",
		"texture_path": "res://Assets/Assets for new version of game/tamagochi/Shop assets/Menu assets/Fish food.png"},
]

static func get_item(id: String) -> Dictionary:
	for row in ROWS:
		if row.id == id:
			return row.duplicate(true)
	return {}

static func validate_inventory(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for id in data:
		if not id is String or get_item(id).is_empty():
			return false
		var count: Variant = data[id]
		if not (count is int or count is float):
			return false
		if not is_finite(float(count)) or count < 1 or count > MAX_COUNT or count != floor(float(count)):
			return false
	return true
