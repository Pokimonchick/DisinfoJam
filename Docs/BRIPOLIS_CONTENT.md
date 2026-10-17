# Bripolis content

Bripolis is a city of anthropomorphic animals governed by cats in the 1990s. Authored sources use personal voices, warmth and irony alongside verifiable civic problems. Period details include paper notices, cassettes, radio requests and telephone booths.

Names follow the animal-city fiction around Никола Коко, господин де Мур, Рататуй and `Le Goutet`. New residents use playful names such as Плотт, Твилл, Мьетта, Бискер and мисс Оул. Avoid ordinary Russian given names and patronymics, and do not impose an American naming scheme or a real country's institutions on the city.

## Catalog and provenance

- `Data/article_catalog.gd` combines 24 base stories, eight earlier user stories, 18 additional Codex stories and two new user sources: **52 articles / 156 headlines**. The 24 base and 18 additional Codex stories now use individual voices, concrete scenes and recurring details; stable IDs, headline types and balance values are retained.
- `Data/community_articles.gd` preserves the user stories, with the revised letter from Mr Mur retained by request. Codex adapted duplicate headline types so each article offers facts, sensation and state support. Mur's first two headlines retain their original wording; the third adds a cat-tail joke while keeping its inspection-support meaning and effects.
- `Data/bripolis_articles.gd` contains the 18 new stories with explicit `provenance` (`author: Codex`, `kind: authored`). This is fictional authored content; it uses no network generation.
- `Data/district_letters.gd` contains the user's `ginger_cats_letter` and `ginger_coal_notice`, with light copy-editing and Codex headlines. An anxious letter about missing ginger cats and a separate industrial coal-dust notice share the district «Рыжие Пушистики»; neither source states the inferred explanation as a proven finding.
- `Data/story_chains.gd` contains Codex continuations around the user stories. Only source text changes; the shared plot, evidence and outcomes stay intact.
- `Docs/OriginalArticles/community_articles_original.gd` is an exact copy from before the headline adaptation. It is excluded from the live catalog but is read during legacy-save recovery to identify old stable headline indices.
- `Docs/OriginalArticles/article_catalog_before_lively.gd` and `bripolis_articles_before_lively.gd` preserve the former Codex prose. `district_letters_user_original.md` preserves the two new user sources. These reference copies are not appended to the live catalog.

## Connections the reader can notice

- «Рыжие Пушистики», coal dust, a stained cap and cats whose colour changes after rain recur in otherwise separate letters and transport scenes. The anxious writer has suspicions, not evidence of kidnapping.
- Плотт and мадам Фолио connect the library's wet books, flood diary and trial evening collection; a father's Friday promise links the diary to Брист's delivery story without fixing their order in the queue.
- Клёп's teacher, his repairer father and the mistaken dedication on «Хвост FM» share ordinary family details without turning each appearance into a formal sequel. Cassettes preserve both public radio and private voices.
- Бискер's mismatched mittens, a tiny mitten embroidered with a key, a cart with a blue ribbon and crooked brass bells recur as small recognisable details. Repetition can invite a connection without proving that every similar object is the same object.

Keep these links in incidental details and character voices. Only the four chains below impose publication order; the rest of the city need not explain itself to the reader.

## New stories

| ID suffix (`bripolis_…`) | Source / topic | State context |
| --- | --- | --- |
| `last_trolley` | Hare conductor; last service cancelled | Criticism of transport cuts |
| `flood_boats` | Beaver librarian; flood rescue | Confirmed rescue work |
| `cassette` | Fox; family recording found | Municipal lost-property assistance |
| `tail_turnstile` | Raccoon tailor; trapped coat | Inadequate equipment testing |
| `pigeon_antenna` | Pigeon radio technician; interference rumour | Housing office supplies repair cable |
| `maternity_window` | Hedgehog midwife; backup generator | Working public purchase |
| `bread_queue` | Mouse baker; bread reserved for a janitor | Inspection found no hidden surcharge |
| `clock_wages` | Squirrel mechanic; unpaid wages | Confirmed public payroll delay |
| `phone_booth` | Tortoise guard; missed family call | Fault and announced repair |
| `lost_glasses` | Owl teacher; glasses returned | Evening lost-property collection |
| `mayor_portrait` | Fox artist; painted frame and wrong whiskers | Contract rebuts gold-frame rumour |
| `squirrel_stall` | Squirrel vendor; unequal sign inspections | Unequal enforcement |
| `evening_dance` | Boar teacher; adult dance class | City provides a room |
| `clinic_numbers` | Retired dog; confusing appointment slips | Confirmed administrative correction |
| `hedgehog_library` | Hedgehog guard; book for his daughter | Trial evening book collection |
| `radio_dedication` | Raccoon repairer; mistaken dedication | Municipal radio corrects an error |
| `bridge_planks` | Beaver carpenter; false completion report | Proven discrepancy in public works |
| `shelter_keys` | Dog caretaker; temporary rooms after a fire | One month of confirmed housing aid |

## Headline balance

`editorial_type` is explicit: 0 = `Факты`, 1 = `Сенсация`, 2 = `Поддержка власти`. Stable option indices can differ from types in community articles; shuffled UI positions do not change those indices.

Use [BALANCE.md](BALANCE.md) for current magnitudes. Private facts usually leave loyalty unchanged; confirmed public benefits can raise it, while accurate criticism can lower it. Honest emotional headlines need no falsehood penalty. Evidence-backed support can improve both reputation and loyalty; invented praise damages reputation.

`money` stores catalog-scale base income. The session applies `roundi(money × combo × (0.35 / 1.5))`. Negative effects already use the current balance scale; do not double them again.

## Chains and source variants

- `cats`: `cats_rumor` → `cats_denial` → `cats_taxi`.
- `rat`: `rat_chef` → `rat_complaint` → `rat_resolution`.
- `bloom`: `bloom_poem` → `bloom_letter`.
- `ginger`: `ginger_cats_letter` → `ginger_coal_notice`.

`VARIANTS[followup_id][previous_choice_index]` provides three full source versions for each of five follow-ups. The key is the stable chosen index of the immediate predecessor in its chain, not the combo type or the shuffled button position. Without a recorded predecessor choice, the original text remains.

The `ginger` pair uses its fixed user sources and has no choice-dependent variants. Its ordering helps the two papers meet in a campaign without supplying an explicit solution to the reader.

| Predecessor | Index 0 | Index 1 | Index 2 |
| --- | --- | --- | --- |
| `cats_rumor` | Unsupported spying accusation | Cautious account of anonymous letter | Avoid accusing cats from one letter |
| `cats_denial` | Appeal not to believe gossip | Denial reported as the organization's position | Denial recast as confession |
| `rat_chef` | Suspicion based on the cook's species | Fair treatment of the cook | Support for sanitary inspection |
| `rat_complaint` | Complaint presented as established fact | Open question about the fur | Avoid dismissing inspection without evidence |
| `bloom_poem` | Anonymous poem without guessed recipient | Speculation about a colleague | Happiness attributed to cat authorities |

The original stories do not establish that the Cat Chancellery is a state institution. Support headlines favour restraint toward unproven accusations. In the romance column, government praise is deliberately unsupported and costs reputation.

## Queue and save behavior

`Scripts/article_sequence.gd` (`ArticleSequence`) manages a finite queue. A new campaign shuffles all 52 articles, moves chain members into an early window of 24 slots, restores their narrative order, and inserts a standalone article between adjacent parts of the same chain. On a later shift, eligible continuations move forward after the carried unfinished draft. The draft stays in place and provides separation from the previous shift's last publication.

There is **no mandatory publication minimum**. Ending shifts immediately can leave chains unfinished; early placement and continuation promotion do not guarantee seeing every story.

Variants replace only an original community catalog body. Manually edited source bodies loaded from saves are preserved. The current draft is pinned during queue migration and next-shift promotion. Legacy recovery keeps the published history, adds missing catalog IDs and orders only eligible remaining slots; already-published chain parts cannot be reordered retroactively.

When a legacy or manually rewritten predecessor headline differs from the current variant's expected wording, the continuation keeps its baseline body. Recovering an index does not justify quoting a different publication.
