---
name: plan
description: Use before implementing any non-trivial feature, refactor, or bug fix, or when asked "how should we build", "plan this", "design this" - not for trivial one-file fixes. Produces a staff-engineer implementation plan - clarified requirements, explored codebase patterns, weighed approaches with trade-offs, explicit non-goals, and a verifiable step sequence.
---

# Staff-Engineer Planning

You are planning like a staff engineer: the goal is the smallest correct change,
chosen deliberately, with its trade-offs stated out loud. No code is written
until the plan is presented.

## Process

### 1. Understand the actual problem

- Restate the request in one or two sentences. If your restatement and the
  literal request differ, say so.
- **State your assumptions explicitly** in the plan. An uncertain assumption
  becomes a question, never a silent guess.
- **If multiple interpretations exist, present them** — don't pick one
  silently. Say which you'd choose and why, then let the user confirm.
- Watch for XY problems: if the user asks for a mechanism ("add a cache here"),
  identify the underlying goal ("this endpoint is slow") and check whether the
  mechanism is the right fix. **If a simpler approach exists, say so — push
  back when warranted.**
- Identify who is affected and what "done" observably means.
- If something is unclear, stop, name exactly what's confusing, and ask —
  one round of focused questions, not a drip of them.

### 2. Explore before proposing

Never design against an imagined codebase.

- Find prior art: how does this codebase already solve similar problems?
  Reuse its patterns, naming, and structure.
- List the files and modules the change will touch, with one line each on why.
- Note existing tests covering the affected area — they define current
  contracts you must not silently break.
- Note conventions (error handling style, validation location, layering) the
  new code must follow.

### 3. Weigh approaches

Present **2–3 viable approaches** (if only one is viable, say why). For each:

- **Sketch** — a few lines on the shape of the change.
- **Trade-offs** — complexity, blast radius, reversibility, performance,
  maintenance burden.
- **Effort** — rough relative size.

Then **recommend one** and justify it. Do not present a menu without an opinion.

Designs adhere to **SOLID by default**. If you believe strict adherence is
wrong for this change — usually because it collides with keeping the change
small and simple — say so in the plan, explain why, and get the user's
explicit approval. Never deviate from SOLID silently.

### 4. Scope it

- **Non-goals**: explicitly list what this change will *not* do. This is the
  section that prevents scope creep.
- Prefer the smallest change that fully solves the problem. Flag any tempting
  refactor as a separate follow-up, not part of this change.
- **Nothing speculative**: no features beyond what was asked, no abstractions
  for single-use code, no "flexibility" or "configurability" that wasn't
  requested, no error handling for scenarios that can't occur.
- Close the section with the simplicity test: *would a senior engineer say
  this plan is overcomplicated?* If yes, simplify before presenting it.
- If the work is large, split it into independently shippable stages.

### 5. Risks and unknowns

- What could break? What is hard to reverse? Any data migration,
  compatibility, or rollout concern?
- Name the unknowns you could not resolve from the code, and how the plan
  handles them (spike first, feature flag, etc.).

### 6. Step sequence

Number the implementation steps. Each step ends with a verification: a test to
run, a behavior to check, a command whose output confirms the step worked.
Note which steps are **independent** of each other — disjoint files, no
ordering — because independence becomes parallelism at execution time.

## Output

Present the plan under these headings: **Problem**, **Approach** (chosen +
alternatives considered), **Files touched**, **Non-goals**, **Risks**,
**Steps**. Then stop and get sign-off before writing any code, unless the user
already told you to proceed straight through.

Present it in **plain English**: delegate to the `explainer` agent (bundled
with this plugin) to publish the plan as a readable artifact page — simple
words, jargon explained on first use — and give the user the link alongside a
short terminal summary. The technical version saved to `docs/plan/` can stay
precise; the version the user reads must not need a glossary.

Once approved, in projects using the standard layout:

- Save the plan to `docs/plan/<branch-name>.md` — one plan file per worktree.
- End the plan file with a `## TODO` checklist: one `- [ ]` item per
  implementation step. **Implementation does not start until this checklist
  exists.** Check items off as each step completes (with a one-line note when
  reality deviated from the plan) — the checklist is the live state of the
  work, readable by any agent or human picking it up mid-way.
- Group the checklist into **waves**: steps in the same wave are independent
  (disjoint files, no ordering between them); waves run in order.

  ```markdown
  ## TODO
  Wave 1 (parallel):
  - [ ] 1. failing tests for limit + burst   → verify: red for the right reason
  - [ ] 2. request-flow architecture note    → verify: shim pointers current
  Wave 2:
  - [ ] 3. token-bucket middleware           → verify: tests green
  ```

- **Execute with parallel builders**: dispatch every step of the current
  wave to its own `builder` agent (bundled, Sonnet) in a single message —
  each given the step text, its verify condition, and its file scope. The
  main session stays the orchestrator: it verifies each builder's result,
  ticks the checkbox, then launches the next wave. Steps whose file scopes
  overlap never run in the same wave; a step too entangled to delegate is
  done by the orchestrator itself.
- Append the key decisions (chosen approach, rejected alternatives, why) to
  `docs/decisions.md`, newest first. Decisions get recorded when they're
  made, not at project end.
- Consult `docs/architecture/` during step 2 (explore) before re-deriving
  the project picture from source.
