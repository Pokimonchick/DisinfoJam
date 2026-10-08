class_name ArticleSequence
extends RefCounted

const STORIES = preload("res://Data/story_chains.gd")
const EARLY_WINDOW := 24

# The queue is finite. Only unpublished slots may move after a run starts.
static func shuffle(articles: Array[NewsArticle], random: RandomNumberGenerator) -> void:
	for index in range(articles.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var previous := articles[index]
		articles[index] = articles[other]
		articles[other] = previous
	var window := mini(EARLY_WINDOW, articles.size())
	for index in range(window, articles.size()):
		if chain_for(articles[index].id).is_empty():
			continue
		var available: Array[int] = []
		for slot in window:
			if chain_for(articles[slot].id).is_empty():
				available.append(slot)
		if not available.is_empty():
			var slot := available[random.randi_range(0, available.size() - 1)]
			var previous := articles[slot]
			articles[slot] = articles[index]
			articles[index] = previous
	order_remaining(articles, 0)

static func chain_for(article_id: String) -> String:
	for key in STORIES.CHAINS:
		if article_id in STORIES.CHAINS[key]:
			return key
	return ""

static func order_remaining(articles: Array[NewsArticle], start: int) -> void:
	for chain in STORIES.CHAINS.values():
		var slots: Array[int] = []
		var members: Array[NewsArticle] = []
		for index in range(start, articles.size()):
			if articles[index].id in chain:
				slots.append(index)
				members.append(articles[index])
		members.sort_custom(func(a: NewsArticle, b: NewsArticle): return chain.find(a.id) < chain.find(b.id))
		for index in slots.size():
			articles[slots[index]] = members[index]
	# Moving a standalone material between adjacent chain parts keeps all chain
	# orders intact. Never move a published prefix or the pinned current draft.
	for index in range(maxi(1, start), articles.size()):
		var chain := chain_for(articles[index].id)
		if chain.is_empty() or chain != chain_for(articles[index - 1].id):
			continue
		for candidate in range(index + 1, articles.size()):
			if chain_for(articles[candidate].id).is_empty():
				var separator := articles[candidate]
				articles.remove_at(candidate)
				articles.insert(index, separator)
				break

static func promote_continuations(articles: Array[NewsArticle], cursor: int, choices: Dictionary, random: RandomNumberGenerator) -> void:
	if cursor >= articles.size():
		return
	var candidates: Array[String] = []
	for chain in STORIES.CHAINS.values():
		for index in range(1, chain.size()):
			if choices.has(chain[index - 1]) and not choices.has(chain[index]):
				candidates.append(chain[index])
				break
	# Pin the unfinished draft, and put follow-ups after it. This also guarantees
	# another material between yesterday's last publication and its continuation.
	var insertion := cursor + 1
	while not candidates.is_empty():
		var id: String = candidates.pop_at(random.randi_range(0, candidates.size() - 1))
		for index in range(insertion, articles.size()):
			if articles[index].id == id:
				var article := articles[index]
				articles.remove_at(index)
				articles.insert(insertion, article)
				insertion += 1
				break
	# A moved follow-up may itself have separated another chain's parts.
	order_remaining(articles, cursor + 1)

static func resolve(article: NewsArticle, choices: Dictionary, history: Array = []) -> NewsArticle:
	if article == null or not STORIES.VARIANTS.has(article.id):
		return article
	var chain: Array = STORIES.CHAINS[chain_for(article.id)]
	var previous: String = chain[chain.find(article.id) - 1]
	if not choices.has(previous):
		return article
	for entry in history:
		if entry.get("article_id", "") != previous:
			continue
		for row in preload("res://Data/community_articles.gd").ROWS:
			if row.id == previous and row.options[int(choices[previous])][0] != entry.get("headline", ""):
				# A legacy or manually rewritten headline can share an index but mean
				# something else. Keep baseline prose rather than quote it incorrectly.
				return article
	# Preserve a source manually edited in a saved run. Authored continuations
	# only replace the catalog's original body, never custom player content.
	for row in preload("res://Data/community_articles.gd").ROWS:
		if row.id == article.id and row.text != article.source_text:
			return article
	var variant: String = STORIES.VARIANTS[article.id].get(int(choices[previous]), article.source_text)
	var resolved := NewsArticle.from_row(article.to_row())
	resolved.source_text = variant
	return resolved
