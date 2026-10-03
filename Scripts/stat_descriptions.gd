extends RefCounted


static func text_for(stat: String, balance: NewsroomBalance) -> String:
	match stat:
		"health":
			return "ВЫНОСЛИВОСТЬ\nСилы редактора расходуются во время работы и при публикации.\nВосстанавливайте их едой и сном дома, а кофе выпивайте на работе.\nПри нуле выносливости наступает истощение — кампания заканчивается."
		"reputation":
			var support: StatBenefit = balance.reader_support
			return "РЕПУТАЦИЯ КОМПАНИИ\nДоверие читателей к правдивости газеты. Проверенные сведения укрепляют доверие, выдумки и искажение фактов снижают его.\nПри нуле репутации офис подожгут — кампания заканчивается.\nПри репутации от %d публикация тратит %d выносливости вместо %d." % [int(support.threshold), int(maxf(0.0, balance.publication_health_cost - support.amount)), int(balance.publication_health_cost)]
		"loyalty":
			var approval: StatBenefit = balance.state_approval
			return "ЛОЯЛЬНОСТЬ ГОСУДАРСТВУ\nОтношение власти к тому, как газета изображает государство. Даже правдивая критика может снизить лояльность; неполитические материалы могут не влиять на неё.\nПри нуле лояльности редактора арестуют — кампания заканчивается.\nПри лояльности от %d в начале смены восстанавливается до %d выносливости, один раз за смену." % [int(approval.threshold), int(approval.amount)]
	return ""
