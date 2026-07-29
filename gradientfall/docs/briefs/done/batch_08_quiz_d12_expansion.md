# Batch: quiz — difficulty 1–2 expansion (the playable band)

**Assignment:** 30 quiz entries, ALL at `difficulty` 1 or 2, spread across the
topics listed below. Aim for roughly half D1 and half D2.

**Why this batch exists (read this, it changes what you write):** the game gates
quiz difficulty by campaign progress — D1–2 anywhere, D3 only after Shrine 3,
D4 after Shrine 6, D5 in the Citadel. The whole of Phase 1 therefore draws from
**D1–2 only**. The bank has 41 questions but just 17 in that band, across only
two topics, and one knowledge-channel cast spends up to three of them — so a
player exhausts everything the game can ask in about five casts and starts
seeing repeats in a single evening. D3–5 entries do not help Phase 1 at all.
**Do not write anything above D2 for this batch.**

**Topics to cover** (use the exact enum string; ~5 entries each):
`models` · `training` · `evaluation` · `overfitting` · `data` · `ml_basics`

**Difficulty, concretely:**
- **D1** — one step, definitional. A player who has read one paragraph about
  the topic gets it. "Which of these is a label?"
- **D2** — one small inference, or telling two neighbouring ideas apart.
  "A model scores 99% on data it trained on and 62% on new data. What happened?"
- Never D3+: no maths, no architecture internals, no jargon a newcomer
  hasn't met.

**Tone:** plain, warm, all-ages, concrete. This is the one place in Gradientfall
where the plain technical words ARE allowed — "model", "dataset", "training",
"label" are all fine here, because the quiz is the game teaching openly. (The
in-world voice rule that bans that vocabulary applies to NPCs, POIs, monsters
and lore, NOT to quizzes.) No ML puns, no character voice, no Bit. Nobody is
speaking these — they are the question itself.

**The explanation is the point.** Every entry carries one, and the player sees
it whether they answered right or wrong. It must say *why* the right answer is
right, in one or two sentences a twelve-year-old follows. Do not merely restate
the correct choice. A good explanation teaches someone who guessed.

**Rules for the choices:**
- Exactly 4, all plausible to someone who half-knows the topic.
- Wrong answers should be *common misconceptions*, not nonsense — a joke option
  makes the question free.
- No "all of the above" / "none of the above". No two choices that are both
  defensible. Vary which index is correct (do not put the answer at 2 every time).
- Keep each choice under ~90 characters so it fits the card on one or two lines.

**Canon you must respect:**
- Everything must be factually correct ML. This is a teaching game; a wrong
  answer key is the worst possible bug and the review will reject the batch.
- Use everyday examples over abstract ones: house prices, spam, weather,
  flowers, bike rentals, handwriting. The meadow's own dataset is Fisher's
  irises (sepal/petal measurements, three families) — iris examples are
  especially welcome and land as recognition for the player.
- `id` must match `^quiz_[a-z0-9_]+$` and be unique. Use
  `quiz_<topic>_b08_<two-digit number>`, e.g. `quiz_models_b08_01`.

**Schema (every entry must match `content/schemas/quiz.schema.json`):**

```json
{
  "id": "string, ^quiz_[a-z0-9_]+$",
  "topic": "one of: ml_basics, data, models, training, evaluation, neural_networks, overfitting, nlp_llms, computer_vision, reinforcement, ethics_alignment",
  "difficulty": "integer 1-5 (THIS BATCH: 1 or 2 only)",
  "question": "string, 10-300 chars",
  "choices": ["exactly 4 strings, each 1-120 chars"],
  "answer_index": "integer 0-3",
  "explanation": "string, 20-400 chars"
}
```
No extra fields — the validator rejects unknown properties.

**Worked example (match this quality and voice):**

```json
{
  "id": "quiz_ml_basics_ui8uwi",
  "topic": "ml_basics",
  "difficulty": 1,
  "question": "In a dataset for predicting house prices, which value is the label?",
  "choices": ["The number of bedrooms", "The postal code", "The final sale price", "The floor area"],
  "answer_index": 2,
  "explanation": "The label is the outcome the model should predict. Here, house details are input features, while the final sale price is the answer being learned."
}
```

**Output:** a single JSON array of 30 entries. Valid JSON only — no markdown
fences, no commentary. Save as `content/inbox/quizzes/batch_08.json`.
