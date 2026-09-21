---
name: retro
description: Look back at this session for moments the environment failed you, and propose deterministic fixes over prose.
disable-model-invocation: true
---

# Retrospective

Look back at what just happened and propose changes to the **environment** —
not the code — so the next session hits less friction.

## What it reads

This session's conversation, `git log <base>..HEAD` and `git diff --stat`,
test output from the run, and any plan file under `docs/plan/` — what was
expected against what actually happened. Default to the current session
unless the user names another one.

## Where to look

Each category names a place the environment can be strengthened, and when
it's worth opening.

- **Navigation** — the agent spent turns finding the right file. Fix: a
  pointer in `docs/architecture` or the `CLAUDE.md` shim.
- **Automated checks** — a mistake shipped that a check would have caught.
  Fix: a test, a git-guard rule, or a CI job. A repo with no guardrail at
  all is itself a finding, not a neutral default.
- **Coding standards** — the reviewer let something through. Classify first:
  **mechanical** (a fixed pattern, a banned API, a file-location rule) gets
  a deterministic check, never prose. **Judgement** (cross-file consistency,
  "matches the surrounding style") gets a sentence in a principle or skill.
- **Tool economy** — a tool call was expensive or repeated. Fix: a `se`
  verb, or a script under `bin/`.
- **No-ops** — a sentence in `PRINCIPLES.md` or `CLAUDE.md` describes
  behaviour the agent already does by default. Fix: delete it.
- **Information access** — a fact existed but the agent couldn't reach it.
  Fix: tee a dev-server log, grant read access, add a doc.

## The rule

Every **mechanical** finding earns one of three outlets: a git-guard rule, a
`se` verb, or a test in `tests/`. Only **judgement** findings become words —
a line in a principle or a skill. When a finding could go either way,
default to building the check: it holds every time, a sentence holds only
when someone remembers to reread it.

## Output

Rank candidates by severity, each stated as:

`what happened (evidence from the session) → classification → proposed
outlet → estimated size`

Delegate to the `explainer` agent to publish the ranked list as a
plain-English artifact page and share the link; keep a compact version in
the terminal too.

## What happens next

This skill proposes; it never edits files. Acting on a candidate is a new
plan and a new worktree, built on this list. The implementation agent that
would do that work carries the most context pressure of the two stages, so
a new prose standard goes to the reviewer by default; the builder carries
only a rule it has to apply while the code is being written.
