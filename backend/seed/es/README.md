# Spanish course (for zh / en speakers)

~3000 words in 10 levels, plus hand-written grammar and dialogue questions.
Levels map roughly onto CEFR: L1–2 ≈ A1, L3–4 ≈ A2, L5–6 ≈ B1, L7–8 ≈ B2, L9–10 ≈ C1.

## Word files — `words_LL.txt`

```
@topic                      ← sets the topic for the lines below it
score|pos|gender|word|zh|en|example|example zh|example en
1.2|n|f|la manzana|苹果|apple|Me como una [manzana].|我吃一个苹果。|I'm eating an apple.
```

- **score** — difficulty in (0, 10]. `level = ceil(score)`. Words are introduced in score order, so the score
  also orders words inside a level (core, high-frequency words first).
  Scored by: frequency in everyday spoken Spanish, usefulness for a beginner's survival situations, and
  morphological difficulty (irregular verbs and false friends are pushed up a little).
- **pos** — n, v, adj, adv, pron, prep, conj, det, num, interj, phr.
- **gender** — nouns only: `m`, `f`, or `mf` (same form for both, *el/la estudiante*). Everything else `-`.
  Nouns are written with their article; feminine nouns starting with stressed *a* keep the real article
  (*el agua* is still `f`).
- **example** — one short, natural sentence using vocabulary from the same level or below. Mark the word
  with `[ ]`. Bracket the **dictionary form** whenever natural (infinitive for verbs — *Voy a [comer]*,
  masculine singular for adjectives, singular noun without the article): those examples automatically
  become vocabulary fill-in questions. An inflected form in brackets is fine but produces no question.

## Question files — `questions_LL.txt`

```
@id fill <level> <topic>
es Nosotros [hablamos] español. | hablan, hablo, hablas
zh 我们说西班牙语。
en We speak Spanish.

@id next <level> <topic>
es ¿Qué quieres beber? >> Un café con leche, por favor.
zh 你想喝什么？ >> 一杯拿铁，谢谢。
en What would you like to drink? >> A coffee with milk, please.
```

### Explanations — `why` lines

Every `fill` question explains each of its options (the answer and every distractor), in Chinese and
English, shown after the learner checks an answer. Add them at the end of the question block:

```
why es.zh la | manzana 是阴性单数名词，用 la
why es.zh el | el 是阳性冠词，manzana 是阴性
why es.en la | manzana is feminine singular, so "la"
…
```

`why <target>.<native> <option> | <reason>` — keep it short (a few words to one sentence) and say
*why*, not just "correct"/"wrong". A test fails if an option is missing. Vocabulary clozes need no
`why` lines: they are explained from the word list automatically.

## Progression

| Level | Vocabulary cloze (generated) | Word forms (`fill`, words ≤ L−1) | Dialogues (`next`, words ≤ L−2) |
|---|---|---|---|
| 1–2 | ✓ only this | — | — |
| 3 | ✓ | articles & gender agreement, ser/estar, regular present | greetings, ordering, basic needs |
| 4 | ✓ | irregular present (tener, ir, hacer, poder, querer…), gustar | shopping, directions, family |
| 5 | ✓ | stem-changing verbs, reflexives, possessives, ir a + inf | daily routine, plans, health |
| 6 | ✓ | preterite (regular + common irregular) | past weekend, travel stories |
| 7 | ✓ | imperfect vs preterite, object pronouns | childhood, describing the past |
| 8 | ✓ | present perfect, future, conditional, por/para | work, plans, polite requests |
| 9 | ✓ | present subjunctive (wishes, emotions, doubt), commands | advice, opinions, complaints |
| 10 | ✓ | imperfect subjunctive, si-clauses, connectors | debates, hypotheticals, formal |

A learner's level is the level of the hardest word they have met in the swipe deck. Vocabulary questions
unlock once their word has been introduced; grammar and dialogue questions unlock at their level, and by
construction only use vocabulary from one or two levels below — so they review, never ambush.
