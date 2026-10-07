extends SceneTree

# Run --report to refresh the catalogue and five-day balance report.
# Run without --headless and add --ui to also exercise the real screens.
const SEEDS := [1, 7, 11, 23, 42, 73, 101, 202, 999, 12345, 65537, 314159]
const POLICIES := ["facts", "balanced", "two_sensations", "sensations", "state"]
const NAMES := {"facts": "Правдивые материалы", "balanced": "Осторожная смешанная", "two_sensations": "Две ложные сенсации + факты", "sensations": "Только дорогие сенсации", "state": "Максимизация лояльности"}
var failures: Array[String] = []
var runs: Array[Dictionary] = []
var benchmarks: Array[Dictionary] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func fresh(seed_value: int, income: float = -1.0) -> NewsroomSession:
	var session := NewsroomSession.new()
	session.balance = load("res://Data/mvp_balance.tres").duplicate(true)
	if income >= 0.0:
		session.balance.publication_income_multiplier = income
	session.reset(seed_value)
	return session

func day_counts(session: NewsroomSession, seconds: float = 30.0) -> Array[int]:
	var counts: Array[int] = []
	var size := session.articles.size()
	for day in session.balance.campaign_days:
		counts.append(size / session.balance.campaign_days + (1 if day < size % session.balance.campaign_days else 0))
	# The inspector currently starts at 30 stamina. A slow reader can finish
	# the first shift earlier and distribute that work over the remaining days.
	if seconds >= 60.0 and session.balance.starting_health < 50 and counts[0] > 5:
		var deferred := counts[0] - 5
		counts[0] = 5
		for day in range(1, counts.size()):
			var moved := mini(deferred, session.balance.publication_limit - counts[day])
			counts[day] += moved
			deferred -= moved
	return counts

func best_option(session: NewsroomSession, field: String, editorial_type: int = -1, false_only := false) -> int:
	var best := -1
	var options := session.current_article().headlines
	for index in options.size():
		var option: HeadlineOption = options[index]
		if editorial_type >= 0 and option.editorial_type != editorial_type:
			continue
		if false_only and option.reputation >= 0:
			continue
		if best < 0 or option.get(field) > options[best].get(field):
			best = index
	return best

func choose(session: NewsroomSession, policy: String, slot: int) -> int:
	var truthful := best_option(session, "reputation")
	if policy == "facts":
		return truthful
	if policy == "sensations":
		return best_option(session, "money", 1)
	if policy == "state":
		var loyal := best_option(session, "loyalty")
		return loyal if session.current_article().headlines[loyal].loyalty > 0 else truthful
	if policy == "balanced":
		# Repair reader trust before pursuing money; respond to state pressure.
		if session.reputation < 42:
			return truthful
		if session.loyalty < 50:
			var loyal := best_option(session, "loyalty")
			return loyal if session.current_article().headlines[loyal].loyalty > 0 else truthful
		if slot not in [0, 1] or session.reputation < 50 or session.loyalty < 55:
			return truthful
	if (policy == "balanced" and slot in [0, 1]) or (policy == "two_sensations" and slot in [0, 3]):
		var sensational := best_option(session, "reputation", 1, true)
		if sensational >= 0:
			return sensational
	return truthful

func rest_bundle(session: NewsroomSession, next_count: int, seconds: float, policy: String) -> Array[int]:
	var b := session.balance
	var cost := b.publication_health_cost
	if policy == "facts" and session.reputation >= b.reader_support.threshold:
		cost = maxf(0, cost - b.reader_support.amount)
	var need := next_count * (cost + seconds * b.health_drain_per_second) + 15.0
	var available := session.health + b.sleep_health
	if session.loyalty >= b.state_approval.threshold:
		available += b.state_approval.amount
	if session.coffee_ready:
		available += b.coffee_health_restore
	var cheapest := 1000000
	var result: Array[int] = [0, 0, 0]
	for meals in range(3):
		for snacks in range(4):
			for coffee in range(2):
				if coffee > 0 and session.coffee_ready:
					continue
				var price := meals * b.meal_price + snacks * b.snack_price + coffee * b.coffee_price
				var supply := available + meals * b.meal_health + snacks * b.snack_health + coffee * b.coffee_health_restore
				if supply >= need and price < cheapest:
					cheapest = price
					result = [meals, snacks, coffee]
	return result

func simulate(seed_value: int, policy: String, seconds: float, income: float = -1.0) -> Dictionary:
	var s := fresh(seed_value, income)
	var counts := day_counts(s, seconds)
	var result := {"seed": seed_value, "policy": policy, "seconds": seconds, "income": s.balance.publication_income_multiplier, "days": [], "articles": [], "publications": []}
	s.start_shift()
	for day in counts.size():
		var day_start := s.money
		var completed_before := s.completed_shifts
		for slot in counts[day]:
			if s.phase != NewsroomSession.Phase.WORK:
				break
			if s.coffee_ready and s.health <= s.balance.maximum_stat - s.balance.coffee_health_restore:
				s.drink_coffee()
			s.tick_work(seconds)
			if s.phase != NewsroomSession.Phase.WORK:
				break
			var selected := choose(s, policy, slot)
			s.publish_headline(s.option_order.find(selected))
			result.articles.append(s.last_result.article_id)
			result.publications.append(s.last_result.duplicate(true))
			if s.phase == NewsroomSession.Phase.WORK:
				s.acknowledge_publication()
		if s.phase == NewsroomSession.Phase.WORK:
			s.finish_shift()
		var after_rent := s.money
		var bundle: Array[int] = [0, 0, 0]
		if s.phase == NewsroomSession.Phase.HOME:
			bundle = rest_bundle(s, counts[day + 1], seconds, policy)
			for _item in bundle[0]:
				if s.phase == NewsroomSession.Phase.HOME:
					s.buy_food(true)
			for _item in bundle[1]:
				if s.phase == NewsroomSession.Phase.HOME:
					s.buy_food(false)
			if bundle[2] > 0 and s.phase == NewsroomSession.Phase.HOME:
				s.buy_coffee()
		result.days.append({"day": day + 1, "count": s.published_today, "income": s.earned_today, "cash_start": day_start, "rent": s.balance.rent if s.completed_shifts > completed_before else 0, "cash_after_rent": after_rent, "cash": s.money, "purchases": after_rent - s.money, "health": s.health, "reputation": s.reputation, "loyalty": s.loyalty, "bundle": bundle, "ending": s.ending})
		if s.phase != NewsroomSession.Phase.HOME:
			break
		s.start_shift()
	result.won = s.campaign_completed
	result.ending = s.ending
	result.total = s.total_published
	result.cash = s.money
	result.reputation = s.reputation
	result.loyalty = s.loyalty
	return result

func _run() -> void:
	var actual := fresh(42)
	check(actual.articles.size() <= actual.balance.campaign_days * actual.balance.publication_limit, "The full queue fits within five shifts")
	var coefficients: Array[float] = [0.45, 0.40, 0.35]
	if actual.balance.publication_income_multiplier not in coefficients:
		coefficients.append(actual.balance.publication_income_multiplier)
	for income in coefficients:
		for seconds in [30.0, 60.0]:
			for policy in POLICIES:
				var wins := 0
				var minimum_cash := 1000000
				var maximum_cash := -1000000
				var unique_queues := true
				for seed_value in SEEDS:
					var outcome := simulate(seed_value, policy, seconds, income)
					wins += 1 if outcome.won else 0
					if outcome.won:
						minimum_cash = mini(minimum_cash, outcome.cash)
						maximum_cash = maxi(maximum_cash, outcome.cash)
						var seen: Dictionary = {}
						for article_id in outcome.articles:
							seen[article_id] = true
						unique_queues = unique_queues and seen.size() == actual.articles.size() and outcome.total == seen.size()
					if seed_value == 42:
						runs.append(outcome)
				benchmarks.append({"income": income, "seconds": seconds, "policy": policy, "wins": wins, "minimum_cash": minimum_cash if wins > 0 else 0, "maximum_cash": maximum_cash if wins > 0 else 0})
				if is_equal_approx(income, actual.balance.publication_income_multiplier) and policy in ["facts", "balanced"]:
					check(wins == SEEDS.size() and unique_queues, "Viable five-day complete queues: %s, %d seconds" % [policy, int(seconds)])
				print("income=%.6f seconds=%d policy=%s wins=%d/%d winning_cash=%s" % [income, int(seconds), policy, wins, SEEDS.size(), "%d..%d" % [minimum_cash, maximum_cash] if wins > 0 else "none"])
	var main := simulate(42, "balanced", 30.0)
	check(main.won and main.total == actual.articles.size(), "Cautious mixed play completes five days and the entire queue")
	var seen: Dictionary = {}
	for article_id in main.articles:
		seen[article_id] = true
	check(main.articles.size() == seen.size(), "The five-day campaign publishes every article once")
	check(not simulate(42, "sensations", 30.0).won, "Long false-sensation streaks remain dangerous")
	if "--report" in OS.get_cmdline_user_args():
		_write_report(main)
	if "--ui" in OS.get_cmdline_user_args():
		await _play_ui(main)
	print("BALANCE PLAYTHROUGH: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _cell(value: String) -> String:
	return value.replace("|", "\\|").replace("\n", " ").replace("<", "&lt;").replace(">", "&gt;")

func _save_markdown(path: String, lines: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Report can be written: " + path)
	if file != null:
		file.store_string("\n".join(lines) + "\n")

func _write_report(main: Dictionary) -> void:
	var file := FileAccess.open(OS.get_environment("TEMP").path_join("disinfo-balance-runs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(runs, "\t"))
	var s := fresh(42)
	var b := s.balance
	var table: Array[String] = [
		"# Таблица параметров всех заголовков",
		"",
		"Автоматически получена из Data/article_catalog.gd, Data/community_articles.gd и актуального Data/mvp_balance.tres. Правила назначения новых значений: [BALANCE.md](BALANCE.md).",
		"",
		"В каталоге %d статьи и %d заголовков. Доход: roundi(база × комбо × %.6f); репутация и лояльность: roundi(база × комбо). Колонки ×2 показывают полный размер эффекта; фактическое изменение шкалы ограничивается диапазоном 0–100. Один и тот же тип не означает одну и ту же правдивость." % [s.articles.size(), s.articles.size() * 3, b.publication_income_multiplier],
		"",
		"| Статья | Подача | Заголовок | База $ | Выплата ×1 / ×2 | Репутация ×1 / ×2 | Лояльность ×1 / ×2 | Контекст |",
		"| --- | --- | --- | ---: | ---: | ---: | ---: | --- |",
	]
	for article in preload("res://Data/article_catalog.gd").create_articles():
		for option in article.headlines:
			table.append("| %s — %s | %s | %s | %d | %d / %d | %+d / %+d | %+d / %+d | %s |" % [
				article.id, _cell(article.source_title), HeadlineOption.TYPE_NAMES[option.editorial_type], _cell(option.text), option.money,
				roundi(option.money * b.publication_income_multiplier), roundi(option.money * b.publication_income_multiplier * 2),
				option.reputation, option.reputation * 2, option.loyalty, option.loyalty * 2, _cell(option.explanation)])
	_save_markdown("res://Docs/BALANCE_TABLE.md", table)
	var report: Array[String] = [
		"# Проверка пяти смен",
		"",
		"Получено через настоящие правила NewsroomSession, без подмены денег, выносливости или последствий. Все 32 статьи проходят один раз; очередь и варианты перемешаны по seed. Проверка экранов отдельно воспроизводит смешанное прохождение seed 42 через кнопки выбора, публикации, результата, покупок и кровати.",
		"",
		"Текущий ресурс: старт %d выносливости, %d репутации, %d лояльности, %d $; коэффициент дохода %.6f; аренда %d $ за смену; предел долга %d $. Это включает ручную настройку стартовой выносливости в ресурсе: её не заменяли значением 80 из класса." % [int(b.starting_health), int(b.starting_reputation), int(b.starting_loyalty), b.starting_money, b.publication_income_multiplier, b.rent, b.debt_limit],
		"",
		"Политики используют известные эффекты заголовков и недорогой набор восстановления. Это проверка существования разумного пути; она не гарантирует победу при произвольных покупках, ошибках и времени чтения.",
		"",
		"- **Правдивые материалы:** наиболее достоверный вариант с наибольшим приростом репутации. Иногда это честная сенсационная подача или точное опровержение, поэтому серия фактов может прерваться.",
		"- **Осторожная смешанная:** до двух умеренных ложных сенсаций в начале дня, только при запасе шкал; при низкой репутации — правдивый материал, при низкой лояльности — доступный положительный для власти заголовок.",
		"- **Две ложные сенсации + факты:** две сенсации каждый день без реакции на лояльность; показывает, почему одних последующих фактов недостаточно.",
		"- **Только дорогие сенсации:** выбирает наиболее прибыльный вариант сенсационной подачи.",
		"- **Максимизация лояльности:** выбирает максимальную прибавку лояльности, а если её нет — правдивый вариант; это не всегда тип «поддержка власти».",
		"",
		"Активное время на материал — 30 или 60 секунд. Чтение результатов и сюжетных сцен не расходует силы. Распределение при 30 секундах: 7/7/6/6/6; при 60 секундах и старте 30 сил: 5/9/6/6/6 — первую смену игрок сдаёт раньше. Дома сон и необходимые покупки готовят следующую смену; первая чашка бесплатна.",
		"",
		"## Перемешанные очереди",
		"",
		"12 seed: " + ", ".join(SEEDS.map(func(value: int): return str(value))) + ". Денежный диапазон приводится **только для победивших**; деньги раннего поражения без остальных аренд с ними не сравниваются.",
		"",
		"| Стратегия | Активных секунд на материал | Побед / 12 | Деньги после пяти аренд и покупок |",
		"| --- | ---: | ---: | ---: | ---: |",
	]
	for entry in benchmarks:
		if is_equal_approx(entry.income, b.publication_income_multiplier):
			report.append("| %s | %d | %d / %d | %s |" % [NAMES[entry.policy], int(entry.seconds), entry.wins, SEEDS.size(), "%d…%d $" % [entry.minimum_cash, entry.maximum_cash] if entry.wins > 0 else "Нет завершённых кампаний"])
	report.append_array(["", "## Подбор коэффициента дохода", "", "Расходы и эффекты шкал одинаковы, отличается только выплата. Ниже приведены результаты для каждого коэффициента; временный долг допускается до установленного предела.", "", "| Коэффициент | Секунды | Стратегия | Побед / 12 | Деньги победивших |", "| ---: | ---: | --- | ---: | ---: | ---: |"])
	for entry in benchmarks:
		if entry.policy in ["facts", "balanced"]:
			report.append("| %.6f | %d | %s | %d / %d | %d…%d $ |" % [entry.income, int(entry.seconds), NAMES[entry.policy], entry.wins, SEEDS.size(), entry.minimum_cash, entry.maximum_cash])
	for outcome in runs:
		if not is_equal_approx(outcome.income, b.publication_income_multiplier):
			continue
		report.append_array(["", "## Seed 42: %s, %d секунд" % [NAMES[outcome.policy], int(outcome.seconds)], "", "| Смена | Статей | Доход | Аренда | Покупки | Деньги к концу вечера | Силы | Репутация | Лояльность |", "| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"])
		for day in outcome.days:
			report.append("| %d | %d | %d | %d | %d | %d | %d | %d | %d |" % [day.day, day.count, day.income, day.rent, day.purchases, day.cash, roundi(day.health), roundi(day.reputation), roundi(day.loyalty)])
		report.append("")
		report.append("Результат: %s; напечатано %d / %d. На пятом дне показаны показатели после последней аренды: домой после победы не переходят. При поражении аренда указана только за реально завершённую смену." % [NewsroomSaveData.ENDINGS[outcome.ending], outcome.total, s.articles.size()])
	report.append_array(["", "## Все 32 публикации основного прохождения", "", "Значения ниже — реальные эффекты с комбо, до отсечения шкал на 0/100; порядок соответствует seed 42, смешанной стратегии и 30 секундам.", "", "| № | Статья | Подача | Серия | Множитель | Доход | Репутация | Лояльность |", "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |"])
	for i in main.publications.size():
		var result: Dictionary = main.publications[i]
		report.append("| %d | %s | %s | %d | %.2f | %+d | %+d | %+d |" % [i + 1, result.article_id, HeadlineOption.TYPE_NAMES[result.combo_type], result.combo_count, result.multiplier, result.money, result.reputation, result.loyalty])
	report.append_array(["", "Команда обновления из корня проекта:", "", "~~~powershell", "& 'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script Tests/balance_playthrough.gd -- --report", "~~~", "", "Для пяти смен через настоящие экраны убрать --headless, добавить --ui. Скриншоты этого прохождения сохраняются во временную папку Windows, файл сохранения игрока не используется."])
	_save_markdown("res://Docs/BALANCE_RUNS.md", report)

func _capture(day: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("disinfo-balance-day-%d.png" % day))

func _play_ui(main: Dictionary) -> void:
	check(DisplayServer.get_name() != "headless", "Screen playthrough requires a native renderer")
	if DisplayServer.get_name() == "headless":
		return
	var state := root.get_node("GameState")
	var previous_store: SaveRepository = state.save_store
	var previous_session: NewsroomSession = state.session
	var test_path := "user://balance_play_%d/campaign.json" % Time.get_ticks_usec()
	state.save_store = SaveRepository.new(test_path)
	state.session = fresh(42)
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._new_run(true)
	game.session.reset(42)
	game.session.start_shift()
	await create_timer(0.3).timeout
	var s: NewsroomSession = game.session
	for day in main.days:
		while game.view == game.View.STORY:
			game.get_node("%NarrativePrimary").pressed.emit()
		await create_timer(0.3).timeout
		check(game.view == game.View.WORK, "Work screen on day %d" % day.day)
		for slot in day.count:
			if s.coffee_ready and s.health <= s.balance.maximum_stat - s.balance.coffee_health_restore:
				game.work.get_node("%Coffee").activated.emit()
			s.tick_work(main.seconds)
			game.work._open_choices(false)
			var selected := s.option_order.find(choose(s, main.policy, slot))
			game.work.cards[selected].pressed.emit()
			await create_timer(0.35).timeout
			game.work._publish_selected()
			check(s.awaiting_acknowledgement and game.work.popup.active, "Publication feedback %d" % s.total_published)
			if not s.awaiting_acknowledgement:
				break
			await create_timer(0.3).timeout
			game.work.popup.primary_button.pressed.emit()
			await create_timer(0.23).timeout
		game.work.get_node("%FinishShift").pressed.emit()
		await create_timer(0.3).timeout
		if s.phase == NewsroomSession.Phase.HOME:
			for _item in day.bundle[0]:
				game.home.get_node("%Meal").pressed.emit()
			for _item in day.bundle[1]:
				game.home.get_node("%Snack").pressed.emit()
			if day.bundle[2] > 0:
				game.home.get_node("%Coffee").pressed.emit()
			game._process(0)
		check(s.money == day.cash and is_equal_approx(s.health, day.health) and s.reputation == day.reputation and s.loyalty == day.loyalty, "Native day %d matches the calculated economy and stats" % day.day)
		await _capture(day.day)
		print("UI DAY %d: articles=%d cash=%d stamina=%.1f reputation=%d loyalty=%d" % [day.day, s.total_published, s.money, s.health, int(s.reputation), int(s.loyalty)])
		if s.phase != NewsroomSession.Phase.HOME:
			break
		game.home.get_node("%Bed").pressed.emit()
		game.home.tick_home(0.9)
	while game.view == game.View.STORY:
		game.get_node("%NarrativePrimary").pressed.emit()
	check(s.campaign_completed and s.total_published == main.total and s.money == main.cash and game.view == game.View.ENDING, "The real screens complete five shifts and all 32 articles")
	game._run_active = false
	game.queue_free()
	await process_frame
	state.save_store = previous_store
	state.session = previous_session
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path.get_base_dir()))
