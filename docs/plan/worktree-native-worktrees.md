# Native worktrees inside the repo

## Goal

Switch the worktree convention from sibling directories (`../<repo>-<feature>`)
to Claude Code's **native worktrees inside the repo** (`.claude/worktrees/<name>`),
using the native mechanism (EnterWorktree tool / `claude --worktree`) whenever a
Claude Code session is driving, with plain `git worktree add` into the same
location as the no-Claude fallback.

## Why

- The user wants worktrees inside the project folder.
- The native mechanism already enforces this plugin's rules: it branches from
  fresh `origin/<default-branch>` (`worktree.baseRef: fresh`) and refuses to
  discard uncommitted work at teardown — no reason to roll our own.
- Sessions launched inside a native worktree get their own per-directory
  history in `~/.claude/projects/`, so the `se` board's resume mapping works
  unchanged (verified against fancy-chat's store).

## Facts verified before writing

- `claude --worktree [name]` / EnterWorktree create `.claude/worktrees/<name>`
  on branch `worktree-<name>` off fresh `origin/<default>` (confirmed live in
  this repo).
- `.claude/worktrees` was only ignored on this machine via the global
  `~/.gitignore` — repos need a deterministic per-repo ignore
  (`.git/info/exclude`, no commit to main required).
- `bin/se` parses `git worktree list --porcelain` with zero path assumptions —
  nested worktrees are already first-class rows; no script change needed.
- EnterWorktree re-homes the session's transcript to the worktree's project
  dir in `~/.claude/projects/` (verified with this very session), so `se`'s
  per-directory resume mapping works for entered and launched sessions alike.

## TODO

- [x] `skills/worktree/SKILL.md` — rewrite creation (§1: native-first,
      `.claude/worktrees/`, ignore check), parallel/resume notes (§2), and
      teardown (§5: ExitWorktree path + manual path) → verify: no `../`
      sibling references remain.
- [x] `skills/setup/SKILL.md` — scaffold adds the worktrees ignore check;
      adoption triage wording drops "sibling-directory convention" → verify:
      grep.
- [x] `PRINCIPLES.md` §8 — worktree location named explicitly → verify: read.
- [x] `README.md` — usage step 2 and guard example use the new location →
      verify: grep for `../` worktree refs.
- [x] Validate plugin manifest (`claude plugin validate`, marketplace
      swap-aside) → verify: exit 0.
- [x] Run `bin/se` in this repo with this worktree present → verify: board
      shows `.claude/worktrees/native-worktrees` row with this plan's TODO.
