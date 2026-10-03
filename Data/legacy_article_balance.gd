extends RefCounted

# Original effects are checked before updating known authored headlines.
const ORIGINAL_EFFECTS: Dictionary = {
	"black_cat": [[7, 0], [-15, -4], [-9, 9]],
	"market_gate": [[8, 2], [-16, -10], [-9, 10]],
	"court": [[8, -3], [-35, -28], [-12, 14]],
	"tram": [[7, -4], [-14, -8], [-5, 8]],
	"bakery": [[8, 0], [-12, 0], [-8, 9]],
	"water": [[9, -8], [-36, -30], [-13, 14]],
	"park": [[7, 4], [-13, -7], [-9, 10]],
	"museum": [[8, 1], [-15, -6], [-10, 10]],
	"school": [[9, -10], [-34, -27], [-14, 15]],
	"fire_drill": [[7, 3], [-14, -5], [-8, 9]],
	"cheese_price": [[8, -2], [-15, -8], [-9, 10]],
	"curfew": [[8, -4], [-33, -32], [-12, 14]],
	"library": [[8, 2], [-16, -12], [-8, 9]],
	"festival": [[7, 2], [-13, -6], [-9, 9]],
	"bus_photo": [[9, 3], [-38, -28], [-11, 12]],
	"mayor_quote": [[8, 3], [-15, -10], [-9, 11]],
	"shelter": [[8, 2], [-14, -7], [-10, 11]],
	"archive": [[9, 4], [-37, -30], [-12, 14]],
	"rent": [[8, -6], [-15, -9], [-10, 11]],
	"police_bike": [[7, 4], [-15, -8], [-10, 12]],
	"canteen": [[9, -8], [-36, -30], [-13, 14]],
	"electricity": [[8, 1], [-15, -9], [-9, 10]],
	"rumor_chain": [[9, -2], [-16, -10], [-11, 12]],
	"petition": [[9, -7], [-38, -34], [-13, 15]],
	"cats_rumor": [[-10, -10], [3, 4], [-10, -8]],
	"cats_denial": [[6, 8], [-6, -6], [-14, -12]],
	"cats_taxi": [[4, 8], [2, -10], [-16, -14]],
	"rat_chef": [[-4, -8], [6, 8], [-12, -14]],
	"rat_complaint": [[-5, -10], [7, 4], [-14, -16]],
	"rat_resolution": [[15, 8], [5, 12], [-18, -16]],
	"bloom_poem": [[4, 0], [-4, 0], [-12, -10]],
	"bloom_letter": [[8, 0], [-10, 0], [-10, -8]],
}

static func apply(articles: Array[NewsArticle]) -> int:
	var changed := 0
	var catalog: Dictionary = {}
	for current in preload("res://Data/article_catalog.gd").create_articles():
		catalog[current.id] = current
	for saved in articles:
		if not saved.provenance.is_empty() or not catalog.has(saved.id):
			continue
		var current: NewsArticle = catalog[saved.id]
		if saved.source_title != current.source_title or saved.source_text != current.source_text:
			continue
		for option in saved.headlines:
			for i in current.headlines.size():
				var authored: HeadlineOption = current.headlines[i]
				var original: Array = ORIGINAL_EFFECTS[saved.id][i]
				if option.text != authored.text or option.editorial_type != authored.editorial_type or option.money != authored.money:
					continue
				if option.reputation != original[0] or option.loyalty != original[1]:
					continue
				if option.reputation != authored.reputation or option.loyalty != authored.loyalty:
					option.reputation = authored.reputation
					option.loyalty = authored.loyalty
					option.explanation = authored.explanation
					changed += 1
				break
	return changed
