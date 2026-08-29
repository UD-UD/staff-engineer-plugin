# Ponytail adoptions

## Goal

Adopt six patterns from DietrichGebert/ponytail (MIT), critically reviewed on
2026-08-30, each adapted to this plugin's philosophy (deterministic scripts
over LLM calls, correctness-first review, personal single-platform use).

## What we're taking and why

1. **The ladder** — ponytail's 7-rung "stop at the first rung that holds"
   replaces Simplicity First's vague "would a senior engineer say this is
   overcomplicated?" with a procedure. Rung 2 (reuse what's already in the
   codebase — look before you write) is a real gap in our principles.
2. **Debt markers** — deliberate shortcuts get an `se-debt:` comment naming
   the ceiling and the upgrade trigger; approved SOLID deviations leave one
   too. Harvested by `se debt` — a grep, zero LLM tokens (ponytail uses an
   LLM skill for this; we do it deterministically).
3. **❌/✅ review-output grammar** — show the forbidden verbose finding next
   to the wanted one-liner; scripted empty case. Keeps our 10-category
   correctness-first hunt and Blocker/Should-fix/Consider ranking.
4. **SubagentStart hook** — builders/reviewers currently never see the
   principles; inject a trimmed digest deterministically. SessionStart stays
   matcher-less on purpose (matches every source, including compact).
5. **Trigger-phrase descriptions** — enumerate exact user phrasings and
   negative scope in skill descriptions; capped, since descriptions are
   always-on tokens.
6. **Permanent tests + CI** — stop writing throwaway fixtures; `tests/` in
   the repo, GitHub Actions on macOS (real bash 3.2).

Explicitly rejected: multi-platform adapters, intensity modes/flag files,
gain scoreboard, full benchmark rig (honesty pattern noted for later).

## TODO

Wave 1 (parallel builders, disjoint files):
- [x] `bin/se`: `debt` subcommand — grep `se-debt:` markers into a ledger,
      `no-trigger` tag, summary line, help text → verified: builder fixture
      + independent re-check both correct.
- [x] `PRINCIPLES.md` §2 ladder + §5 debt-marker line, new
      `PRINCIPLES-SUBAGENT.md` digest, `hooks/hooks.json` SubagentStart →
      verified: diff reviewed, JSON parses, digest 21 lines, net +13.
- [x] Skills description pass (8 skills, trigger phrases + negative scope,
      ≤60 words each) + ❌/✅ grammar in review skill/staff-reviewer →
      verified: diff reviewed, all descriptions 35-60 words, frontmatter parses.

Wave 2 (after wave 1 verified):
- [x] `tests/` suite porting git-guard + se fixtures (status, env, baseline,
      teardown, debt) + `.github/workflows/test.yml` (macos) + README
      (commands table, credits ponytail MIT) → verify: `tests/run.sh` green
      locally under /bin/bash.

Wrap-up:
- [x] Orchestrator verification: full diff review, tests re-run, plugin
      validate, then commit + push + PR (no attribution).
