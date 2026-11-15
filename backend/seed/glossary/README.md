# Glossaries — tap-to-translate for quiz sentences

Every word that appears in a quiz question (prompt sentences and dialogue replies) must be
explainable when the learner taps it. Words that are in the course word list are looked up
there; this folder covers everything else: inflected forms (*quiero*, *allons*), articles,
names, and so on. A test fails if a quiz word is covered by neither.

One file set per target language, `<target>_*.txt`. The first non-comment line names the
meaning columns, e.g. `!columns zh en` (the learner's native languages).

```
form|lemma|pos|<meaning in each column language>
quiero|querer|v|（我）想要|I want
```

- **form** — the word exactly as it appears in a sentence, lower-case (Chinese: the word itself).
- **lemma** — dictionary form (infinitive, masculine singular; nouns with their article).
- **pos** — n v adj adv pron prep conj det num interj phr name.
- Meanings are short and fit the way the word is used in the course sentences; for a
  conjugated verb, mention the person/tense when it helps (*fui* — I went / I was).
