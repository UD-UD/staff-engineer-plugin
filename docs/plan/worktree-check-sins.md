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
(Part 1 only — Part 2 below adds Codex, an `se` verb, and a `review` change.)
- No Codex / second-model pass inside check-sins.
- No hook, no automatic gate, no new `se` verb in part 1.
- No change to `review` or `staff-reviewer` in part 1.
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

---

# Part 2: optional Codex integration

Status: APPROVED 2026-10-06 (r3). Implemented; self-review fixes below. r2 acted on all 5 inquisitor sins; r3
acted on Codex's second opinion (scopes, completion contract, inline
review path, failure test) — user, 2026-10-06.

## Problem
When the Codex CLI is installed and logged in, `se` should offer it as a
second model at the three points where a different model's blind spots help
most — a freshly generated plan, a code review, a stuck debug — and behave
exactly as today when it is not.

## Decisions already made (user, 2026-10-06)
- Codex plugs into `plan`, `review` and `debug`. Not inside `check-sins`
  (declined earlier), not builders. (`pr` was added 2026-10-07 — see TODO 16.)
- Always offered in one line, never automatic. In `plan`, one combined offer
  with check-sins: "Check this plan for sins? (+ Codex second opinion)";
  each check still runs separately and independently.
- Detection: `se codex` — CLI on PATH, then `codex login status`.
- No per-project off switch; declining is the off switch.

## Facts found
- Codex CLI 0.160.0; `codex login status` exits 0 when logged in (~0.05s).
- `codex review` takes `--uncommitted`, `--base <branch>`, `--commit <sha>`;
  no commit range, no PR. `codex exec -s read-only -o <file>` runs with no
  write access and saves the final answer to a file.
- The Codex plugin's `/codex:review` and `/codex:adversarial-review` are
  `disable-model-invocation: true`; skills cannot call them. We call the CLI.
- Dogfood lesson: Codex read a plan file that was being rewritten under it.
  Codex is always given a snapshot, never a live file.

## Approach
- **`se codex`** (new verb, zero LLM): `codex: ready (<version>)` exit 0;
  `codex: not installed` exit 1; `codex: installed but not logged in — run
  codex login` exit 1. Added to both case lists in `bin/se` (validation and
  dispatch) and the usage block.
- **Run contract (all three call sites):** Codex gets a snapshot written
  once for this run (`scratchpad/codex-<site>-input.md`) and writes a fresh
  result file (removed before the run). The skill collects the task, checks
  the exit status, and reads the result only if this run wrote it. Any
  failure is reported as `Codex failed: <reason>`, never as "no findings".
- **`plan`**: the existing check-sins offer becomes the combined offer when
  `se codex` is ready (unchanged when not). The offer names what leaves the
  machine: "the plan text goes to Codex (OpenAI)". On yes: `codex exec -s
  read-only` on the plan snapshot and the repo — never the session's
  reasoning or the inquisitor's findings. Its points are shown beside the
  check-sins report (agreements marked) and go through the same act /
  accept / reject round.
- **`review`**: once the first review is done — delegated to staff-reviewer
  or inline — offer Codex only for the two scopes where it reviews the same
  diff: uncommitted (`codex review --uncommitted`) and the **current branch**
  against its base (`codex review --base <base>`). Commit ranges, other
  branches and PRs: no offer, and say why in one line. Codex runs in the
  background; the first report is presented as today; Codex findings arrive
  as an addendum — each passes "Verification before reporting", is tagged
  `[codex]`, duplicates noted as "both models found it", page re-published.
  An accepted second opinion finishes before the review's final verdict.
- **`debug`**: step 4 gains the missing loop-back — a killed hypothesis
  moves to the next; when every listed hypothesis is dead, return to step 3
  for a new list, or — if `se codex` is ready — offer a Codex diagnosis. The
  offer says what is sent: the red command, the minimised repro, and the
  ruled-out hypotheses with their evidence, all through the Redact rule
  first. `codex exec -s read-only`. Codex diagnoses only; its answer becomes
  a new hypothesis tested by the normal loop; the fix still lands with a
  regression test (step 5).
- **Part 1 reconciled**: part 1 Non-goals scoped (done in this plan);
  `docs/decisions.md` "Rejected — a second-model (Codex) pass" becomes
  "Rejected — a Codex pass inside check-sins"; new decision entry for Codex.

Alternatives considered:
- *Call the Codex plugin's `/codex:*` commands* — rejected: not invocable by
  skills; would depend on another plugin's file layout.
- *`command -v codex` only* — rejected: a logged-out Codex fails mid-run.
- *Let the model detect Codex* — rejected: mechanical → `bin/se`.
- *Codex writes the debug fix* — rejected: bypasses regression-test-first.
- *Codex on ranges/PRs via `--commit` per SHA or a diff in `exec`* —
  rejected: N runs or a hand-built diff; the result is not the reviewed diff.
- *Scripted end-to-end tests of the skill text* (Codex point 5) — rejected:
  skills are prose an LLM follows; no deterministic runner exists. The
  testable parts (`se codex` outcomes incl. failure) are tested; the rest
  gets live checks.

## Files touched
- `bin/se` — `codex` verb (both case lists + usage).
- `tests/test-se.sh` — `se codex` outcomes with stub `codex` on a fakebin
  PATH (existing pattern): ready, not installed, not logged in.
- `skills/plan/SKILL.md` — combined offer + run contract.
- `skills/review/SKILL.md` — scoped offer, addendum, run contract.
- `skills/debug/SKILL.md` — step-4 loop-back + redacted hand-off.
- `docs/decisions.md` — reword the Rejected entry; add the Codex entry.
- `README.md`, `CHANGELOG.md`.

## Non-goals
- No Codex inside check-sins or as a builder.
- No config switch, hook, or stop-gate; no dependency on the Codex plugin.
- Nothing changes when Codex is absent — no nag, no hint.

## Risks
- Codex CLI flags change → skills name exact commands; `se codex` prints
  the version.
- Data leaves the machine → every offer names what is sent; debug redacts.
- Slow Codex runs → background; the first report never waits, but the
  final verdict does.

## Part 2 TODO
Wave 1 (parallel):
- [x] 7. failing tests for `se codex`: ready / not installed / not logged in → verify: red for the right reason (unknown command)
- [x] 8. `plan` combined offer + run contract → verify: wording unchanged when Codex absent; offer names what is sent
- [x] 9. `review` scoped offer + addendum + run contract → verify: no offer for range/PR/other-branch scopes; verdict waits for an accepted Codex run
- [x] 10. `debug` step-4 loop-back + redacted hand-off → verify: offer reachable only after every hypothesis is dead
- [x] 11. decisions.md reworded + Codex entry → verify: `grep -n Codex docs/decisions.md` shows no unscoped rejection
Wave 2:
- [x] 12. `se codex` verb → verify: step-7 tests green; full suite green
- [x] 13. README + CHANGELOG → verify: suite green
Wave 3:
- [x] 14. live checks, following the worktree's skill text → verify: `bin/se codex` prints ready; with codex hidden from PATH `bin/se codex` exits 1 and no offer is made; a Codex review addendum on this branch yields `[codex]` findings or an explicit "Codex: no findings"
  (`se codex` ready/exit 0; hidden from PATH → `not installed`/exit 1. `codex review --base main` returned 2 `[codex]` findings, both verified and fixed. Self-review fixes from staff-reviewer + Codex: every offer now says Codex can read any repo file — read-only stops writes, not reads; `--base` offered only on a clean tree; review's first verdict is provisional and restated after the addendum, and no edits while Codex runs (review cannot snapshot — Codex reads the live tree); plan starts Codex first and check-sins joins its points into its own round, with Codex-only runs recorded per check-sins step 4.)
- [x] 15. smoke tests: headless `claude -p --plugin-dir` sessions on a throwaway fixture repo, user answers given in the prompt → verify: each flow runs as written with the plugin installed
  (A plan + check-sins + Codex, B review + Codex, C review with Codex hidden, D debug hand-off: all pass. Fixed on the way: skills called `se codex` from PATH, which is the main checkout's older `bin/se` with no `codex` verb, so the offer silently never appeared; skills now call `"${CLAUDE_PLUGIN_ROOT}/bin/se" codex`. `codex review` saved its whole working log; review now uses `codex exec review … -o` for the final answer only. The model once dispatched the inquisitor directly with a placeholder prompt; its description now says check-sins only. Codex can read `scratchpad/`, where the session's own theory and check-sins reports live; the plan and debug instructions now tell it to read nothing there but its input. Not plugin bugs, from the test setup: writes under `.claude/` are refused in headless acceptEdits; scratchpad-guard refuses a fixture placed inside the harness temp dir.)
- [x] 16. one offer per PR (user, 2026-10-07): `pr` step 1 runs `review` without its Codex offer; step 3 makes the combined "sins (+ Codex)" offer, Codex on `--base` only with a clean tree, its points joining check-sins' round → verify: smoke E (`/se:pr` headless) shows exactly one offer line and both halves run
  (smoke E passed: one offer line; review's own Codex offer skipped as caller=pr; `codex exec review --base main` exit 0, no findings; check-sins PENANCE, 4 sins all accepted → PR body `## Risk`.)
