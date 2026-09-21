---
name: grill
description: Grill the user with rounds of targeted questions to turn a fuzzy design into a shared understanding. Use when the user says "grill me", "stress-test this", "interview me about" something, or another skill (plan, setup) needs to resolve a fuzzy design before acting.
---

# Grilling

Interview the user until the design is a shared understanding, not a guess.
Map the design as a **tree of decisions**: every decision branches into the
decisions that hang off it, and some branches only make sense once an
earlier one is settled.

## Rounds

The **frontier** is every question whose prerequisites are already settled —
the ones you can ask right now without guessing at an answer you haven't
heard yet. Ask the whole frontier in one round, numbered, each with your
recommended answer, then wait. A question that depends on another question
still open in this round belongs to a **later** round, not this one.

Format each round like this:

```
❓ **Q1** - **<question title>**: <question body>
➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body>
➡️ <your recommended answer>
```

Each answer reshapes the tree: it settles a branch and can unblock questions
that were waiting on it. Recompute the frontier and ask the next round.

## Two rules

- **Facts are your job.** Look them up before asking. If a frontier question
  needs something from the filesystem or git history, dispatch the Explore
  agent to find it instead of asking the user to recall it — and keep the
  rest of the frontier moving while that lookup runs; only the questions
  downstream of it wait.
- **Decisions are the user's.** Anything that isn't a fact — a preference, a
  trade-off, a scope call — goes to the user as a question, with your
  recommendation attached so they can just confirm it.

## Done when

The frontier is empty: every branch of the tree has been visited and nothing
is left silently assumed. Report the shared understanding and wait for the
user to confirm it before acting on it — what happens next belongs to
whichever skill called you (`plan`, `setup`, ...); grilling only produces
the understanding.

This is Principle 1 — "don't assume, ask" — worked one decision at a time
until nothing is left unasked.
