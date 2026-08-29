---
name: setup
description: Use when starting a new project or bringing an existing one up to the standard self-contained layout - scratchpad/ agent sandbox, docs/architecture/, docs/decisions.md, docs/plan/, and a thin CLAUDE.md shim that routes into them.
---

# Standard Project Layout

Every project is self-contained in its directory:

```
<project>/
├── CLAUDE.md              # thin shim: summary + pointers into docs/
├── scratchpad/            # gitignored agent sandbox
├── docs/
│   ├── architecture/      # complete overview: data flow, control flow, mappings
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
  worktree setup: files to copy, dirs to symlink, post-create/pre-delete
  commands — the worktree skill creates and maintains it). If understanding the project requires
  reading source cold, this folder is incomplete.
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
   and `docs/plan/` stating their purpose.
2. Start `docs/decisions.md` with the entry format:

   ```markdown
   # Decision Log
   Newest first. Append an entry whenever a significant decision is made.

   ## YYYY-MM-DD — <decision title>
   **Decision:** what was decided.
   **Why:** the driving constraint or goal.
   **Rejected:** alternatives considered and why they lost.
   ```

3. Write the `CLAUDE.md` thin shim (or trim an existing fat one — with the
   user's approval, moving its content into `docs/`):

   ```markdown
   # <Project name>

   <One-paragraph summary: what this project is and does.>

   ## Where things live
   - Architecture & complete overview: `docs/architecture/`
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
   - `/se:review` before every commit; `/se:commit` to commit; `/se:pr` for PRs

   Also:
   - New features start in a worktree off main; never commit to main.
   - Record decisions in `docs/decisions.md` as they are made.
   - Present plans, reviews, and explanations in plain English (the
     `explainer` agent publishes them as artifact pages).
   - Keep this file a thin shim — details belong in `docs/`.
   ```

4. For an existing project: audit against this layout, report the gaps, and
   fill them on approval. Seed `docs/architecture/` from what you learn
   exploring the codebase — that exploration is expensive; write it down so
   no agent pays for it twice.

## Keeping it alive

Whenever structure, data flow, or dev-environment behavior changes, update
the affected `docs/architecture/` file and, if pointers changed, the
`CLAUDE.md` shim — in the same change, not "later".
