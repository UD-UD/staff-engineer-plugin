# Adopt the worthwhile ideas from mattpocock/skills

Source: the critical review published 2026-09-20
(https://claude.ai/artifact/NGHsF1WDJ13NZJCJopyZck). This plan covers every
item that review marked "adopt" (Tiers 1–3) and none it marked "not to adopt".

## Problem

se enforces process well (hooks, `se` CLI, gates, fresh-eyes review) but is
thin on *method* in four places: it has no interview technique for the plan
stage, no debugging discipline at all, its test rules miss three named
anti-patterns, and its reviewer never checks the diff against the plan it was
built from. Around those, the skill descriptions are written as summaries
rather than triggers (about 400 always-loaded words), the decision log has
no admission rule, and the repo has no changelog or manifest check.

## Assumptions

- "Good suggestion" means the review's whole adopt list, not only Tier 1.
  Every item is small enough that the total stays one worktree; if that
  reading is wrong, drop steps from the TODO rather than reshaping the plan.
- `disable-model-invocation: true` is a supported SKILL.md frontmatter key
  for plugin skills. Confirmed against code.claude.com/docs/en/skills before
  this plan was presented: the description is hidden from the model and only
  the user can type the command.
- The plugin stays Claude Code specific. Nothing here adds cross-harness
  metadata.

## Approach

**Chosen: extend what exists, add three small skills, script the one
mechanical piece.** Each borrowed idea lands in the skill that already owns
that moment (plan, test, review, setup). Three ideas have no home and become
skills of their own: `grill` (the interview primitive, model-invoked so
`plan` and `setup` can call it), `debug` (the six-phase loop), and `retro`
(user-invoked; proposes checks, not prose). The only new enforcement is a
git-guard rule refusing a commit while a `[DEBUG-xxxx]` tag survives in the
tree, because cleanup is mechanical and prose checklists are where Pocock's
own skills admit they fail.

Considered and rejected:

- **One large "method" skill holding grilling, debugging and test rules.**
  Fewer files, but it would be always-loaded as one description and fire
  for the wrong moments. Pocock's two-loads argument applies: split by the
  trigger word actually used.
- **Inline the interview into `plan` only.** Cheaper, but `setup`'s adoption
  audit needs the same rounds, and a 25-line primitive is the right size to
  share.
- **Run `claude plugin validate` in CI.** Needs the CLI installed on the
  runner and the marketplace manifest moved aside (known quirk). A bash
  manifest test in the existing suite checks the same invariants with no
  new dependency, and can assert it fails on a broken fixture.
- **A `se debug` verb listing tags.** The guard's refusal message already
  names the files. Nothing to add.
- **Rewriting PRINCIPLES.md wholesale for positive phrasing.** The file is
  load-bearing and injected every session. Pair each prohibition with its
  positive target where one is missing; leave the rest.

SOLID: not applicable; no code with types is added. The guard rule follows
the existing one-rule-one-block shape.

## Files touched

New:
- `skills/grill/SKILL.md` — the interview primitive: design tree, frontier,
  rounds, numbered questions each with a recommended answer; facts are the
  agent's job, decisions the user's; ends only when nothing is left silently
  assumed.
- `skills/debug/SKILL.md` — feedback loop first (red-capable, deterministic,
  fast, agent-runnable), minimise, 3–5 falsifiable hypotheses shown to the
  user, one variable at a time, tagged logs, regression test before fix,
  cleanup. Tag format written as `[DEBUG-xxxx]` so the skill file itself
  never matches the guard's hex pattern.
- `skills/retro/SKILL.md` — user-invoked. Reads this session and the branch;
  classifies each finding as mechanical (→ propose a git-guard rule, `se`
  verb, or test) or judgement (→ propose a principle or skill edit).
- `tests/test-manifest.sh` — plugin.json and hooks.json parse; every
  `skills/*/SKILL.md` has `name` equal to its directory and a `description`;
  every `agents/*.md` has `name`, `description`, `tools`; no
  `[DEBUG-<hex>]` literal anywhere tracked; plus a negative fixture proving
  the test can fail.
- `CHANGELOG.md` — 0.1.0 (PRs 1–13, one line each) and 0.2.0 (this branch).
- `hooks/scripts/scratchpad-guard.sh` + `tests/test-scratchpad-guard.sh`
  (added mid-wave-1 at the user's request) — PreToolUse on Write, Edit and
  Bash: any target inside the harness temp scratchpad is refused, the
  project's `scratchpad/` is created if missing and ignored through
  `info/exclude` if nothing ignores it yet, and the message names the path.
  `hooks/hooks.json` gains the matcher; `PRINCIPLES-SUBAGENT.md` gains one
  line so every delegated agent knows before it tries.
- `docs/architecture/glossary.md` is *not* created here; `setup` gains the
  template, and this repo gets one only if a later change needs it.

Edited:
- `hooks/scripts/git-guard.sh` — Rule 6: on `git commit`, run
  `git grep -lE --untracked '\[DEBUG-[0-9a-f]{4}\]'` in `cwd`; block with
  the file list if any hit.
- `tests/test-git-guard.sh` — fixture repo with a tagged line: blocked; same
  repo after removing it: allowed; the literal built by `printf` so the test
  file never contains it.
- `skills/plan/SKILL.md` — step 1 calls `grill`; step 2 reads
  `docs/architecture/glossary.md` if present and greps `docs/decisions.md`
  for prior rejections of each candidate approach; step 4 adds
  expand → migrate → contract for wide mechanical refactors; TODO items
  state behaviour + verify, and the "may touch" file list is computed by
  the orchestrator at dispatch time from the current tree; decisions
  appended only when all three gates hold (hard to reverse, surprising
  without context, real trade-off); description rewritten as a pointer.
- `skills/test/SKILL.md` — three named anti-patterns (tautological,
  side-channel verification, horizontal slicing) and the pre-agreed seam
  rule; description rewritten.
- `agents/builder.md` — name the seam being tested at in the report; the
  tautological and side-channel rules in one line each.
- `PRINCIPLES-SUBAGENT.md` — "Tests are sacred" line gains "expected values
  come from an independent source, never recomputed the code's way".
- `agents/staff-reviewer.md` + `skills/review/SKILL.md` — a separate
  `## Plan conformance` block: TODO items missing or half-done, work outside
  the plan checked against Non-goals, items done wrong. Never merged into
  the severity ranking. One line when no plan file exists. Plan path is
  resolved with the same flattening rule `se` uses.
- `skills/setup/SKILL.md` — `disable-model-invocation: true`; decisions.md
  template header carries the three-gate rule; layout and shim gain
  `docs/architecture/glossary.md` (term, one-line meaning, `Avoid:`
  synonyms); adoption audit calls `grill` for its questions; "done when" per
  scaffolding step; description rewritten.
- `skills/worktree/SKILL.md`, `skills/commit/SKILL.md`, `skills/pr/SKILL.md`
  — a "Done when" line per step; commit's scan names `[DEBUG-xxxx]` tags
  and points at the guard; descriptions rewritten.
- `skills/status/SKILL.md` — one bullet: at a stage gate also choose
  continue / compact with an instruction / fresh session, in that order;
  description rewritten.
- `agents/explainer.md` — read `docs/architecture/glossary.md` when present
  and use its terms.
- `PRINCIPLES.md` — §6 gains the tautological rule; §3, §6, §7, §10
  prohibitions paired with their positive target where missing. No new
  sections.
- `README.md` — skills 8 → 11, commands table, layout tree gains
  `glossary.md`, a short "You know it is working when" list per skill.
- `.claude-plugin/plugin.json` — version 0.2.0.
- `docs/decisions.md` — one entry: what was adopted from Pocock, what was
  rejected and why (mirrors the review's "not to adopt" table).

## Non-goals

- No issue-tracker abstraction, no spec/ticket skills, no wayfinder.
- No change to `se` CLI verbs, `safe_to_teardown`, or any existing guard rule.
- No same-session review, no auto-commit anywhere.
- No Fowler smell list in the reviewer.
- No CI change beyond what the new test file adds through the existing glob.
- No rewrite of PRINCIPLES.md structure or numbering.
- No glossary written for this repo.

## Risks

- **Guard false positive.** A repo that legitimately ships the string
  `[DEBUG-` followed by four hex characters would be unable to commit. The
  pattern is narrow and the message says exactly which file; acceptable.
  The plugin's own files avoid the literal by construction (test proves it).
- **`git grep --untracked` cost** on a huge tree at every commit. It is
  bounded by tracked + untracked-not-ignored files, the same set `git
  status` walks. Acceptable; measured on this repo in step 3.
- **Description rewrites change when skills fire.** Each rewrite keeps every
  current trigger phrase and only reorders/prunes. Reviewed one by one in
  wave 2's verification.
- **`disable-model-invocation` unsupported.** Would surface as a validate
  error before the PR; fallback is to leave `setup` model-invoked.
- **Scope.** Thirteen steps. Each is independently revertable; the TODO
  order puts the highest-value items first so a cut leaves a coherent set.

## Steps

1. `skills/grill/SKILL.md` → verify: file has frontmatter with name `grill`,
   a model-facing description containing "grill", and the round format.
2. `skills/debug/SKILL.md` → verify: frontmatter valid; body contains no
   `[DEBUG-<hex>]` literal (`grep -E '\[DEBUG-[0-9a-f]{4}\]'` returns 1).
3. Test first, then Rule 6 in `git-guard.sh` → verify: new assertions red
   before the rule, `bash tests/run.sh` green after; `time` of the grep on
   this repo printed in the report.
4. `tests/test-manifest.sh` → verify: `bash tests/run.sh` shows it PASS on
   the current tree; its negative fixture assertion passes (proves it can
   fail).
5. `skills/retro/SKILL.md` → verify: `disable-model-invocation: true`
   present; body names the mechanical/judgement split and the three
   mechanical outlets (guard rule, `se` verb, test).
6. `agents/staff-reviewer.md` + `skills/review/SKILL.md` → verify: both
   mention a separate plan-conformance block, the flattening rule, and the
   no-plan one-liner; ranking section unchanged.
7. `skills/test/SKILL.md` + `agents/builder.md` + `PRINCIPLES-SUBAGENT.md`
   → verify: the three anti-pattern names appear in test; builder report
   section names the seam; subagent digest still under 30 lines.
8. `skills/plan/SKILL.md` → verify: step 1 calls grill; decisions.md grep
   and glossary read in step 2; expand/contract in step 4; three-gate rule
   in the decisions paragraph; TODO example unchanged in shape.
9. `skills/setup/SKILL.md` → verify: frontmatter has
   `disable-model-invocation: true`; glossary in layout, template, shim;
   three-gate header in the decisions template; each scaffolding step ends
   with "Done when".
10. `skills/worktree`, `commit`, `pr`, `status` SKILL.md → verify: every
    numbered step in worktree/commit/pr ends with a "Done when" line; commit
    mentions `[DEBUG-xxxx]`; status has the continue/compact/fresh bullet.
11. `agents/explainer.md` + `PRINCIPLES.md` → verify: explainer reads the
    glossary; PRINCIPLES §6 has the tautological rule; word count grows by
    under 120 words; numbering intact.
12. Descriptions audit across all 11 skills → verify: each description
    leads with its trigger word, keeps every phrase currently quoted in
    it, and is at most 45 words; `bash tests/run.sh` green (manifest test).
13. `README.md`, `CHANGELOG.md`, `plugin.json`, `docs/decisions.md` →
    verify: `claude plugin validate .` passes (marketplace.json moved aside
    for the run); README skill count matches `ls skills | wc -l`; suite
    green; baseline shows no new failures.

## TODO

Wave 1 (parallel, disjoint files):
- [x] 1. grill skill                          → verify: frontmatter + round format
- [x] 2. debug skill                          → verify: no hex DEBUG literal
- [x] 3. guard Rule 6, test first             → verify: red then green, timing shown
- [x] 4. manifest test                        → verify: PASS + negative fixture (62 checks; suite 161 → 229)
- [x] 5. retro skill                          → verify: user-invoked, three outlets
- [x] 6. reviewer plan-conformance block      → verify: separate block, ranking intact
- [x] 7. test rules (test, builder, digest)   → verify: three names, seam in report
- [x] 14. scratchpad guard (added 2026-09-21 at the user's request during wave 1: a builder wrote its fixture to the harness temp scratchpad) → verify: 21 guard tests red-then-green; refuses Write/Edit/Bash aimed at `/tmp/claude-*/<project>/<session>/scratchpad`, creates the project `scratchpad/` and ignores it via info/exclude, names the path; digest line added
Wave 2 (parallel, disjoint files):
- [x] 8. plan skill                           → verify: grill call, gates, expand/contract
- [x] 9. setup skill                          → verify: user-invoked, glossary, done-when
- [x] 10. worktree/commit/pr/status skills    → verify: done-when lines, tags, boundary bullet
- [x] 11. explainer + PRINCIPLES              → verify: glossary read, §6 rule, <120 words added (+85)
Wave 3 (orchestrator):
- [ ] 12. descriptions audit                  → verify: triggers kept, ≤45 words each
- [ ] 13. README, CHANGELOG, version, decisions → verify: validate passes, counts match, suite green
