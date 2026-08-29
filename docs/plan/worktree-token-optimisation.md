# Token optimisation: mechanical work moves to bin/se

## Goal

Move the mechanical parts of the worktree lifecycle (env setup, baseline
capture, teardown) out of LLM-narrated skill steps and into three new `se`
subcommands — `se env`, `se baseline`, `se teardown <name>` — then slim
`skills/worktree/SKILL.md` down to the judgment calls plus "run `se ...`".
Add a "Quiet Execution" principle and tighten agent report formats so output
tokens are spent on judgment, not narration.

## Why

The plugin already treats the status board this way (`bin/se`, zero LLM,
correct after a reboot — see `deterministic-over-llm` project memory). Env
setup, baseline capture, and teardown are the same kind of mechanical,
scriptable work currently done step-by-step by the LLM inside the worktree
skill. Doing it once in a script means every future feature pays zero output
tokens for the mechanics and gets it right every time; the LLM's job shrinks
to the parts that actually need judgment (deciding *what* baseline commands
are, confirming a merge, deciding whether to discard vs. save stray files).

## Spec summary

- `bin/se env` — reads `docs/architecture/worktree.json` of the current
  checkout, copies files / symlinks dirs from the main checkout, runs
  `hooks.postCreate`, and makes the `.claude/worktrees` ignore deterministic.
  Idempotent.
- `bin/se baseline` — runs `baseline.commands` from `worktree.json`, records
  PASS/FAIL + duration + output tail to `scratchpad/baseline.md`. Always
  exits 0 (a baseline records reality, it doesn't gate on it).
- `bin/se teardown <name>` — refuses on unregistered / cwd-inside / dirty /
  unmerged; otherwise runs `preDelete` hooks, removes the worktree, deletes
  the branch, prunes. No force flag, ever.
- `is_branch_merged` factored out of the status board's existing
  merged-detection logic and reused by `teardown`'s merge gate.
- `PRINCIPLES.md` gets a "Quiet Execution" principle; `builder`,
  `staff-reviewer`, `explainer` agent reports get tightened formats.
- `skills/worktree/SKILL.md` §2/§3/§5 collapse their mechanical steps into
  "run `se env`" / "run `se baseline`" / "run `se teardown <name>`", keeping
  the judgment prose (config authoring, exclusivity, merge confirmation,
  never-discard-silently). File gets shorter overall.
- `README.md` Commands table gets one compact addition for the three
  subcommands. Nothing else touched.

## TODO

- [x] Write this plan.
- [x] `bin/se`: add `json_list` JSON-array helper (python3), `is_branch_merged`
      shared function (factored out of the status loop, which is updated to
      use it instead of duplicating the first-parent check), and `env` /
      `baseline` / `teardown <name>` subcommands + updated `se help` text →
      verify: `se`, `se help` unchanged in behavior; fixture run below.
- [x] `PRINCIPLES.md` — append "## 10. Quiet Execution" in the file's
      existing bold-thesis + bullets format → verify: read, matches format.
- [x] `agents/builder.md` — hard cap the report section at 10 lines unless
      blocked → verify: read.
- [x] `agents/staff-reviewer.md` — findings-only report, no narrative
      preamble/epilogue, max 3 lines per finding → verify: read.
- [x] `agents/explainer.md` — chat reply is the artifact link plus one line
      → verify: read.
- [x] `skills/worktree/SKILL.md` — §2 keeps config schema (add
      `baseline.commands` to the JSON example) + exclusivity/judgment prose,
      mechanical steps become "run `se env`"; §3 becomes "decide
      baseline.commands once, write them into worktree.json, then run
      `se baseline`"; §5 keeps merge-confirmation, ExitWorktree path,
      never-discard-silently, mechanical steps collapse into "run
      `se teardown <name>`" → verify: file is shorter than before (`wc -l`).
- [x] `README.md` — extend the `se` row in the Commands table (or add one
      compact row) for `se env` / `se baseline` / `se teardown` → verify:
      diff is minimal, table renders.
- [x] Fixture test in a temp dir (`mktemp -d`, outside the repo, real bash
      3.2 via `/bin/bash`): git init, worktree.json exercising copyFiles /
      symlinkDirs / postCreate / preDelete / baseline.commands (incl. one
      failing command) → verify: `se env` copies+symlinks+runs
      postCreate+appends info/exclude and is idempotent on a second run;
      `se baseline` writes `scratchpad/baseline.md` with PASS and FAIL
      lines, exits 0; `se teardown feat-x` refuses dirty, refuses unmerged,
      succeeds after merge+clean (worktree gone, branch gone); plain `se`
      still exits 0.
- [x] Plugin validation: marketplace.json swap-aside, `claude plugin
      validate .`, swap back → verify: exit 0 / "valid".
- [ ] Commit (conventional, no AI attribution), push branch, open PR (What /
      Why / How to verify / Risk, no AI attribution).
