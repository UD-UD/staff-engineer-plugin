---
name: worktree
description: Use when starting any new feature or significant change. Creates a dedicated git worktree off main (main is never committed to directly), sets up an isolated dev environment for parallel development, captures a test baseline, and starts the worktree's implementation plan in docs/plan/.
---

# Feature Worktrees

Main is untouched. Every feature lives in its own worktree with its own
exclusive dev environment, so parallel features never fight over ports,
databases, or uncommitted state.

## 1. Create the worktree

Worktrees live **inside the repo** at `.claude/worktrees/<name>` — Claude
Code's native location. Prefer the native mechanism: it already follows this
plugin's rules (branches from fresh `origin/<default-branch>`, refuses to
discard uncommitted work at teardown).

- **From a Claude Code session**: use the `EnterWorktree` tool with a short
  name (letters, digits, dashes — anything else blurs the session-to-directory
  mapping `se` relies on). It creates `.claude/worktrees/<name>` on branch
  `worktree-<name>` and switches the session into it.
- **From the terminal**: `claude --worktree <name>` starts a fresh session in
  a new worktree (add `--tmux` for a dedicated pane).
- **Without Claude** — same location, manual git:

  ```bash
  git fetch origin main
  git worktree add .claude/worktrees/<name> -b feature/<name> origin/main
  ```

- Always branch from fresh `origin/main` (or `main` if there is no remote) —
  the native default (`worktree.baseRef: fresh`) does this already. Never
  branch from another feature branch unless the user says the work stacks.
- Make the ignore deterministic: if `git check-ignore -q .claude/worktrees`
  fails, append `.claude/worktrees/` to `.git/info/exclude` (local-only, so
  no commit to main is needed). Never rely on a machine's global gitignore —
  on another clone the worktrees would pollute `git status` and test runs.

## 2. Set up an isolated environment

Setup is **config-driven**: check `docs/architecture/worktree.json` first and
execute it. If it doesn't exist, create it from what you learn this time —
setup knowledge belongs in config, not in anyone's memory:

```json
{
  "sync": {
    "copyFiles": [".env", ".env.local"],
    "symlinkDirs": []
  },
  "hooks": {
    "postCreate": ["npm ci"],
    "preDelete": []
  }
}
```

- `sync.copyFiles` — untracked files the worktree needs (env files, local
  certs), copied from the main checkout.
- `sync.symlinkDirs` — heavy directories shared by symlink instead of
  reinstalling (big speed win for parallel worktrees). **Caveat:** only
  share a directory like `node_modules` when branches don't change
  dependency versions; when in doubt, leave it out and let `postCreate`
  install fresh.
- `hooks.postCreate` — commands run inside the new worktree (installs,
  codegen, DB migrations for this worktree's own database).
- `hooks.preDelete` — commands run before teardown (stop this worktree's
  containers and dev servers).

Then the isolation rules, with `docs/architecture/dev-environment.md` as the
prose companion:

- **Exclusivity**: this worktree's dev server, test runner, and data stores
  must be runnable while other worktrees run theirs. Unique ports, separate
  database files/schemas, separate cache dirs — derived from the branch name
  or set in the worktree's own env file.
- If the repo hardcodes a port, DB path, or similar shared resource, that's
  a real obstacle to parallel development: propose making it env-configurable
  as a small, separate change.
- Learned something the config or `dev-environment.md` doesn't capture?
  Write it down now, so the next worktree is cheaper.

When setup is done, hand the user the parallel-session one-liner:
`cd .claude/worktrees/<name> && claude` — a second Claude Code session can
work there while this one continues here.

**Resuming tomorrow:** sessions persist on disk per directory, so nothing is
lost by shutting down. Run `se` (the plugin's status command) from any
checkout to see every worktree with its TODO progress and the exact
`claude --continue` command to pick each session back up. This holds however
the worktree session started — `EnterWorktree` re-homes the session's history
to the worktree's directory, so `cd .claude/worktrees/<name> &&
claude --continue` finds it either way.

## 3. Capture the baseline

Immediately after setup, **before any code changes**:

- Run the test suite, lint, and build. Record a summary in the worktree's
  `scratchpad/baseline.md`: pass/fail counts, names of failing tests,
  build/lint status, rough timings.
- Pre-existing failures belong to main, not to this feature. Note them,
  don't fix them (surgical changes) — mention them to the user instead.
- From now on, "done" means: the suite re-run shows **no new failures
  versus this baseline**, and the feature's own tests pass.

## 4. Start the plan

Create `docs/plan/<branch-name>.md` using the plan skill. One plan file per
worktree — that is all `docs/plan/` ever contains. The plan ends with its
`## TODO` checklist; **implementation starts only after the checklist
exists**, and items get checked off as steps complete.

## 5. Finish and tear down safely

Merge to main only via the PR workflow (`pr` skill). Then delete the
worktree — safely, in this order:

1. Confirm the merge actually landed: the branch appears in
   `git branch --merged main`.
2. Run the `preDelete` hooks from `docs/architecture/worktree.json` — stop
   this worktree's containers, dev servers, and anything else it started.
3. Confirm nothing is left to save:
   `git -C .claude/worktrees/<name> status --porcelain` shows no modified or
   untracked source files. (Gitignored `scratchpad/` contents don't count —
   they die with the worktree by design.) If something IS left: never
   discard it silently — commit it to the feature branch as an explicit
   WIP commit or stash it, and tell the user what you found and where you
   put it.
4. Tick the final TODO items in `docs/plan/<branch-name>.md`; the merged
   plan file stays as the record of what was built.
5. Remove it. If the session is currently *inside* the worktree (it got there
   via `EnterWorktree`), use `ExitWorktree` with `action: "remove"` — its
   refusal when uncommitted work remains is the safety; never pass
   `discard_changes: true` without the user's explicit say-so (use
   `action: "keep"` to step out without deleting). Otherwise:
   `git worktree remove .claude/worktrees/<name>` — **never with `--force`**.
   If git refuses, the worktree is dirty; go back to step 3.
6. `git branch -d <branch>` (lowercase `-d` refuses if unmerged — that's the
   safety) and `git worktree prune`. `ExitWorktree remove` deletes the branch
   itself.
