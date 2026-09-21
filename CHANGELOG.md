# Changelog

All notable changes to this project are documented in this file, in
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) style. Newest
release first.

## [0.2.0] - 2026-09-21

Adopts the items marked "adopt" in the mattpocock/skills review (see
`docs/decisions.md`).

### Added

- `grill` skill: a round-based interview primitive — a numbered question
  per round, each with a recommended answer, called by `plan` and `setup`
  to resolve a fuzzy design before acting.
- `debug` skill: a six-phase debugging loop — build a red, deterministic
  feedback loop before any theory, minimise, rank 3-5 falsifiable
  hypotheses, instrument one variable at a time, fix with a regression
  test, then clean up.
- Git-guard Rule 6: refuse a commit while a `[DEBUG-xxxx]` tag survives
  anywhere in the tree.
- `tests/test-manifest.sh`: asserts `plugin.json` and `hooks.json` parse,
  every skill and agent frontmatter is complete, every hook path resolves,
  and no debug-tag literal survives — with a negative fixture proving the
  checks can fail.
- `retro` skill (user-invoked): looks back at the session and branch, and
  classifies each finding as mechanical (a guard rule, `se` verb, or test)
  or judgement (a principle or skill edit).
- A "Plan conformance" block in `staff-reviewer` and `/se:review`: checks
  the diff against its plan's TODO and Non-goals, separate from the
  severity ranking.
- Three named test anti-patterns (tautological, side-channel verification,
  horizontal slicing) in `/se:test`, and the pre-agreed-seam rule.
- `hooks/scripts/scratchpad-guard.sh`: refuses a Write, Edit, or Bash
  command aimed at the harness temp scratchpad; creates the project's own
  `scratchpad/` and ignores it via `info/exclude` if nothing does yet.

### Changed

- `/se:plan`: step 1 now calls `grill`; step 2 reads
  `docs/architecture/glossary.md` and checks `docs/decisions.md` for prior
  rejections; step 4 adds expand -> migrate -> contract for wide mechanical
  refactors; decisions append only when all three gates hold (hard to
  reverse, surprising without context, a real trade-off).
- `/se:setup`: made user-invoked (`disable-model-invocation: true`); gains
  the `docs/architecture/glossary.md` template, the three-gate rule in the
  decisions.md template header, and a "Done when" line per scaffolding
  step.
- `/se:worktree`, `/se:commit`, `/se:pr`, `/se:status`: every numbered step
  now ends with a "Done when" line; `/se:commit`'s scan names
  `[DEBUG-xxxx]` tags and points at the guard; `/se:status` gains the
  continue / compact / fresh-session bullet at a stage gate.
- `PRINCIPLES.md`: prohibitions in §3, §6, §7, and §10 are paired with
  their positive target where one was missing; §6 gains the tautological
  test rule.

## [0.1.0] - 2026-09-20

- Initial release of the se plugin, with a visual README (banner, layers
  diagram, board render). (#1)
- `/se:setup` gains an adoption pass for existing repos: worktree triage,
  CLAUDE.md migration, plan backfill, main baseline. (#2)
- Extend the no-agent-authorship rule from commits to pull requests. (#3)
- Adopt Claude Code's native worktrees, inside the repo. (#4)
- Add deterministic `env` / `baseline` / `teardown` subcommands and quiet
  execution to the `se` CLI. (#5)
- Adopt ponytail patterns: the simplicity ladder, the debt-marker ledger,
  the subagent principles digest, and a CI test suite. (#6)
- Add an annotated, flat `worktree.json` schema, an interactive resume
  picker, and the every-stage-boundary-waits-for-approval principle. (#7)
- Fix session lookup for a flattened worktree path, and name worktrees in
  the resume picker. (#8)
- Add semantic color to CLI output, off whenever output isn't a
  terminal. (#9)
- Fix moved-session duplication (one session in two places is one row) and
  clear disposable local state before removing a worktree. (#10)
- File sessions under the worktree they actually worked in, with a
  grouped resume list. (#11)
- Stop the status board recommending a teardown that `se teardown`
  itself refuses. (#12)
- Flag a merged branch on the board whose plan still has unticked
  items. (#13)
