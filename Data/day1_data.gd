extends RefCounted

const SUMMARY_LINES: Array[String] = [
	"Первая реплика...",
	"Вторая реплика...",
	"Третья реплика..."
]

const EXTRA_LINES: Array[String] = [
	"Дополнительная реплика...",
	"Ещё одна..."
]

const APPROVE_LINES: Array[String] = [
	"Если эти кошки и правда шпионят, статья должна выйти!",
	"Уж кому-кому, а мышам известно: если рядом есть кошачья шерсть, значит жди скорой беды."
]

const DISAPPROVE_LINES: Array[String] = [
	"Обвинить целую организацию из-за городских выдумок? Ты в своем уме?",
	"Если бы каждый слух о кошках был правдой, мне пришлось бы вообще перестать выходить из редакции."
]

const APPROVE_SCORE: int = -20
const DISAPPROVE_SCORE: int = 5
