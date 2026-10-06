# Plan: `/se:check-sins` — the adversarial reviewer

Branch: `worktree-check-sins` · Status: APPROVED 2026-10-06 (category names approved as proposed)

## Problem
`review` checks whether a diff is correct, assuming a competent author; `grill`
asks the user questions. Nothing in the plugin *attacks* a plan or a change —
assumes it is wrong and tries to prove how. The user wants that, offered at
two moments: when a plan is being finalised, and before a PR is opened.

## Decisions already made (user, 2026-10-06)
- Name `/se:check-sins`. Offered (never forced) after a plan is presented and
  before a PR is created; also runnable by hand.
- Runs in its own read-only agent with fresh context — given the plan or diff,
  never the session's reasoning.
- Findings published as a plain-English page via `explainer`; the user picks
  which to act on; rejected ones are noted as `## Dismissed sins` (and, if
  they pass the decision gates, in `docs/decisions.md` as `Dismissed sin — …`,
  revised from `Rejected — …` by the dogfood run — see TODO 6).
- Skeptic is a step inside the one agent, not a separate agent.
- No Codex second opinion.
- Own category names (not premortem's Tiger / Paper Tiger / Elephant).

## Proposed names (to confirm)
| Our name | Meaning |
|---|---|
| **Mortal sin** | breaks it — real, high-cost failure; must be answered before approve/PR |
| **Venial sin** | real but bounded — weakens it; fix or consciously accept |
| **Unconfessed sin** | the uncomfortable thing nobody stated — wrong premise, hidden assumption, the problem behind the problem |
| **Clean** | angles tried that held up — proof of coverage |
Verdict line: **DAMNED / PENANCE / ABSOLVED** `because <the one finding behind it>`.

## Approach
Chosen: **one skill + one agent**, mirroring `review` + `staff-reviewer`.
- `agents/inquisitor.md` — read-only (Read, Grep, Glob, Bash), inherit model.
  Holds the whole attack method so the skill stays thin.
  - Stance: break confidence, not validate it; no credit for intent or
    promised follow-ups; happy-path-only counts as a weakness.
  - Steelman first (two lines), then attack — so it is attacking the real
    plan, not a strawman.
  - Plan mode angles: premise (right problem? cost of doing nothing?),
    pre-mortem ("3 months on, this failed — why?"), hidden assumptions,
    conflicts with its own Non-goals and with `docs/decisions.md` Rejected
    entries, steps without a real verify, irreversible steps, knock-on effects.
  - Change mode angles: trust boundaries, data loss/corruption, rollback /
    retry / partial failure, races and stale state, empty/null/timeout,
    version and schema drift, silent failure, plan-vs-diff drift.
  - Grounding: every sin cites `file:line` or the plan line it hits, and
    states what evidence would disprove it. No citation or no disproof test →
    dropped.
  - Built-in skeptic: before reporting, try to disprove each sin; dismissing
    a real problem is worse than keeping a doubtful one.
  - At most 5 sins; never stack minor objections; style/naming out of scope
    (that is `review`'s job).
  - Fixed report: steelman · sins by class · Clean list · verdict line.
- `skills/check-sins/SKILL.md` — picks mode (plan file / plan text vs. branch
  diff), builds the agent's input (no session reasoning), dispatches, sends
  the report to `explainer`, then asks the user which sins to act on. Max 3
  rounds on the same target; stops early if the same sins repeat. Never edits
  on its own.
- `plan` skill: in Output, when presenting the plan, offer check-sins before
  approval. Accepted sins revise the plan, which is re-presented.
- `pr` skill: new step after self-review/sanity-check, before writing the
  description — offer check-sins; surviving sins that are accepted as risk
  are named in the PR's Risk section.

Alternatives considered:
- *A mode on `review` / `staff-reviewer`* — rejected: opposite stance
  (competent author vs. assume broken) and review is diff-only; mixing them
  blurs both reports.
- *Inline in the main session, no agent* — rejected: the session that wrote
  the plan is the worst one to attack it.
- *Multi-agent debate / validator per finding (bug-hunter, /code-review)* —
  rejected for now: token cost; built-in skeptic first, revisit on false alarms.
- *Always-on or a stop-hook gate* — rejected: user asked to be prompted.

## Files touched
- `agents/inquisitor.md` (new) — the attack method.
- `skills/check-sins/SKILL.md` (new) — orchestration.
- `skills/plan/SKILL.md` — the offer at plan presentation.
- `skills/pr/SKILL.md` — the offer before the PR description.
- `README.md` — badges (skills 11→12, agents 3→4), skills table row, tree line.
- `CHANGELOG.md` — entry.
- `docs/decisions.md` — entry with the rejected alternatives above.

## Non-goals
- No Codex / second-model pass.
- No hook, no automatic gate, no new `se` verb.
- No change to `review` or `staff-reviewer`.
- No new test file: the existing manifest suite already checks every skill's
  and agent's frontmatter generically; the skill itself is prose.

## Risks
- **Noise** — an adversary told to find problems invents them. Mitigation:
  citation + disproof-test rule, 5-sin cap, Clean list legitimises "found
  nothing".
- **Prompt fatigue** — offering at every plan and PR. Mitigation: one-line
  offer, skip is the default-safe answer; trivial work never reaches `plan`.
- **Name drift** — category names appear in agent, skill and README; one
  source (the agent) defines them, the others reference it.

## Steps
Wave 1 (parallel, disjoint files):
1. `inquisitor` agent → verify: manifest suite green; file states both modes,
   grounding, skeptic step, cap, report format.
2. `check-sins` skill → verify: manifest suite green; mode selection, input
   building, explainer hand-off, round cap, user-chooses step all present.
Wave 2 (parallel, disjoint files):
3. Wire the offer into `plan` → verify: offer sits before the approval stop.
4. Wire the offer into `pr` → verify: offer sits after self-review, before
   description; Risk section picks up accepted sins.
5. README + CHANGELOG + decisions.md → verify: badge counts match
   `ls skills agents`; suite green.
Wave 3:
6. Dogfood: run `/se:check-sins` on this branch's diff → verify: a report
   with steelman, cited sins, Clean list and verdict line; act on what holds.

## TODO
Wave 1 (parallel):
- [x] 1. inquisitor agent: both modes, grounding + disproof rule, built-in skeptic, 5-sin cap, fixed report → verify: suite green, all elements present
- [x] 2. check-sins skill: mode pick, context-only input, explainer hand-off, user chooses, 3-round cap → verify: suite green, all elements present
Wave 2 (parallel):
- [x] 3. plan skill offers check-sins before the approval stop → verify: offer precedes "Then stop"
- [x] 4. pr skill offers check-sins after self-review, before description; accepted sins land in Risk → verify: step order reads right
- [x] 5. README badges/table/tree, CHANGELOG, decisions.md entry → verify: badge counts match skills/ and agents/; suite green
Wave 3:
- [x] 6. dogfood /se:check-sins on this branch diff → verify: report has steelman, cited sins, Clean list, verdict line
  (ran the inquisitor prompt via a general-purpose agent — the installed plugin predates it. Verdict PENANCE, 3 Venial sins, all acted on: untracked files now passed to the agent; accepted risks written to the plan file and read by `pr`; dismissed sins logged as `Dismissed sin —`, not `Rejected —`.)
