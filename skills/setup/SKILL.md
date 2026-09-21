---
name: setup
description: Scaffold the se layout (scratchpad/, docs/architecture/, docs/decisions.md, docs/plan/, thin CLAUDE.md) in a new project, or adopt se in an existing repo with a cleanup pass - worktree triage, CLAUDE.md migration, plan backfill, main baseline. Run once per repo.
disable-model-invocation: true
---

# Standard Project Layout

Every project is self-contained in its directory:

```
<project>/
├── CLAUDE.md              # thin shim: summary + pointers into docs/
├── scratchpad/            # gitignored agent sandbox
├── docs/
│   ├── architecture/      # complete overview: data flow, control flow, mappings
│   │   └── glossary.md    # project vocabulary: term, meaning, avoid-list (created lazily)
│   ├── decisions.md       # reverse-chronological decision log
│   └── plan/              # implementation plans, exactly one per worktree
└── <source, tests, config...>
```

## What each piece is for

- **`scratchpad/`** — the sandbox for agents: intermediate files, throwaway
  scripts, captured baselines, analysis output, and generated artifact pages
  (`scratchpad/artifacts/` — where the `explainer` agent writes the HTML it
  publishes). Always gitignored, safe to delete wholesale. Use it instead of
  littering the source tree or `/tmp`.
- **`docs/architecture/`** — everything an agent or human needs for the
  *complete* project picture: data flow, control flow, module/architecture
  mappings, `dev-environment.md` (how to run dev/test envs, including
  per-worktree isolation knobs), and `worktree.json` (machine-readable
  worktree setup: `copy`/`symlink`/`postCreate`/`preDelete`/`baseline`
  entries, each annotated with why it's there — the worktree skill creates
  and maintains it). If understanding the project requires reading source
  cold, this folder is incomplete.
- **`docs/architecture/glossary.md`** — this project's vocabulary: one line
  per term, its meaning, and an `Avoid:` list of synonyms not to use.
  Project-specific terms only, never general programming concepts. Created
  lazily, not scaffolded up front: `/se:plan` and the `explainer` agent read
  it when it's present, and it gains a term the first time a fuzzy word gets
  settled. Example:

  ```markdown
  **Worktree**: a checkout of one feature branch under `.claude/worktrees/`.
  _Avoid_: branch folder, sandbox

  **Board**: the `se status` table of worktrees, sessions, and anomalies.
  _Avoid_: dashboard, report
  ```
- **`docs/decisions.md`** — every significant planning or implementation
  decision, newest first (template below). Append when a decision is made,
  not at the end of the project.
- **`docs/plan/`** — implementation plans only, one file per worktree, named
  after the branch (`docs/plan/feature-sync.md`). Nothing else lives here.

## Scaffolding steps

Be surgical: create what's missing, never reorganize existing docs or code
without asking.

1. Create the folders above; add `scratchpad/` to `.gitignore`. Git doesn't
   track empty dirs, so drop a one-line `README.md` in `docs/architecture/`
   and `docs/plan/` stating their purpose. Worktrees live inside the repo at
   `.claude/worktrees/`, so make sure it's ignored: if
   `git check-ignore -q .claude/worktrees` fails, append `.claude/worktrees/`
   to `.git/info/exclude`.
   Done when: the four directories exist, `git check-ignore -q scratchpad`
   and `git check-ignore -q .claude/worktrees` both succeed.
2. Start `docs/decisions.md` with the entry format:

   ```markdown
   # Decision Log
   Newest first. Append an entry only when the decision is hard to reverse,
   surprising to a future reader without the context, and the result of a
   real trade-off; anything else stays in the plan file.

   ## YYYY-MM-DD — <decision title>
   **Decision:** what was decided.
   **Why:** the driving constraint or goal.
   **Rejected:** alternatives considered and why they lost.
   ```

   Done when: `docs/decisions.md` exists with the header and entry format
   above, ready for its first entry.

3. Write the `CLAUDE.md` thin shim (or trim an existing fat one — with the
   user's approval, moving its content into `docs/`):

   ```markdown
   # <Project name>

   <One-paragraph summary: what this project is and does.>

   ## Where things live
   - Architecture & complete overview: `docs/architecture/`
   - Project vocabulary (when present): `docs/architecture/glossary.md`
   - Decision log (newest first): `docs/decisions.md`
   - Implementation plans (one per worktree): `docs/plan/`
   - Agent sandbox (gitignored): `scratchpad/`
   - Dev environment & worktree isolation: `docs/architecture/dev-environment.md`

   ## Ground rules (agents: follow without being asked)
   This project runs on the `se` plugin workflow. Invoke these skills at the
   right moment — don't wait for the user to type them:
   - `se` (terminal) or `/se:status` when picking work back up — every
     worktree and the session to resume
   - `/se:worktree` when starting any feature or significant change
   - `/se:plan` before implementing anything non-trivial
   - `/se:test` whenever behavior changes or tests fail
   - `/se:debug` when something is broken, throwing, flaky, or slow (build
     the feedback loop before any theory)
   - `/se:review` before every commit; `/se:commit` to commit; `/se:pr` for PRs

   Also:
   - New features start in a worktree off main; never commit to main.
   - Record decisions in `docs/decisions.md` as they are made.
   - Present plans, reviews, and explanations in plain English (the
     `explainer` agent publishes them as artifact pages).
   - Keep this file a thin shim — details belong in `docs/`.
   ```

   Done when: `CLAUDE.md` at the project root matches the shim template,
   with every pointer resolving to a real file.

4. For an existing project, run the full adoption pass below instead of
   just scaffolding.
   Done when: the adoption pass (steps 1-7 below) has been run to
   completion, or the user has explicitly deferred it.

## Adopting an existing repo

Adoption is **audit, then act**: nothing destructive happens until the user
has seen the list and approved it. The order matters.

### 1. Audit — touch nothing yet

- Run `se` for the worktree and session picture; `git worktree list`,
  `git status`.
- Inventory: CLAUDE.md size and content, what `docs/` already holds,
  `.gitignore`, and how dev/test actually runs (package.json scripts,
  Makefile, compose files).
- Present the findings in three groups: worktrees to triage, layout gaps,
  CLAUDE.md state. Then call the Skill tool with "grill" to work through the
  decisions the audit raises (which worktrees to keep, where fat CLAUDE.md
  content should go) — rounds with recommended answers, not a wall of
  questions. Then act group by group, on approval.

Done when: the three groups have been presented and the grilling round has
settled the audit's open decisions.

### 2. Worktree triage — the cleanup

Propose exactly one verdict per existing worktree:

- **Tear down** — branch merged and tree clean → worktree skill, step 5.
- **Preserve, then tear down** — abandoned but dirty → WIP-commit or stash
  to its branch first; uncommitted work is never discarded.
- **Adopt** — still active → keep it, and backfill
  `docs/plan/<branch>.md` (goal, current state, remaining TODO derived
  from its diff) so the board tracks it from now on.
- **Ask** — detached HEAD or unclear purpose → the user decides.

Sibling-directory worktrees (`../<repo>-<feature>`) get the same triage as
ones under `.claude/worktrees/`. Never relocate a surviving worktree — the
`.claude/worktrees/` convention applies to *new* worktrees only.

Done when: every worktree from step 1's inventory has one of the four
verdicts, and torn-down worktrees are gone from `git worktree list`.

### 3. Scaffold the layout

Same pieces as a new project (`scratchpad/` + gitignore entry,
`docs/architecture/`, `docs/decisions.md`, `docs/plan/`). If `docs/`
already has content, fold — don't duplicate: leave existing docs where they
are and index them from `docs/architecture/README.md`. Seed
`docs/decisions.md` with its first entry: adopting the se workflow, plus
every triage verdict from step 2.

Done when: the standard layout exists (folded with any pre-existing docs,
not duplicated) and `docs/decisions.md` has its first entry.

### 4. Slim the CLAUDE.md

A fat CLAUDE.md (hundreds of lines) migrates: split its content into
`docs/architecture/` files by topic, then replace it with the thin shim
(template above) pointing at the new homes. Show the mapping — old section
→ new file — and get approval before moving. Content is **moved, never
dropped**.

Done when: `CLAUDE.md` matches the thin shim template and every section of
the old fat file has a named new home under `docs/`.

### 5. Seed the machine-readable setup

- `docs/architecture/worktree.json` from what the repo shows: env files to
  `copy`, the install command for `postCreate`, services to stop in
  `preDelete` — annotate each entry with why it's there.
- `docs/architecture/dev-environment.md`: how to run dev and tests, and
  which hardcoded ports/DB paths must become env-configurable before
  worktrees can run in parallel — propose those as separate small changes.

Done when: `docs/architecture/worktree.json` and `dev-environment.md` both
exist and describe how this repo actually runs, not a generic template.

### 6. Baseline main

Run the test suite once on main; record results in
`scratchpad/baseline-main.md`. From adoption day forward those failures
belong to main — no feature inherits blame for them.

Done when: `scratchpad/baseline-main.md` exists with the recorded pass/fail
counts from the run on main.

### 7. Verify and land

Run `se` again: remaining anomalies should be only what the user chose to
keep. Then land the adoption like any other change — a feature branch
(e.g. `chore/adopt-se`) and a PR, never a direct commit to main. The
guardrails apply from day one, including to the adoption itself.

Done when: `se` shows no anomalies beyond what the user chose to keep, and
the adoption itself has landed as a merged PR from its own branch.

## Keeping it alive

Whenever structure, data flow, or dev-environment behavior changes, update
the affected `docs/architecture/` file and, if pointers changed, the
`CLAUDE.md` shim — in the same change, not "later".
