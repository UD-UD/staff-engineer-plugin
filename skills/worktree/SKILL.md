---
name: worktree
description: Use when starting any new feature or significant change, or asked to "start a feature" or begin a "new feature". Creates a dedicated git worktree off main (never commit to main directly), sets up an isolated dev environment for parallel development, captures a test baseline, and starts the worktree's implementation plan in docs/plan/.
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

Setup is **config-driven**: `docs/architecture/worktree.json` holds the
config, `se env` executes it. If the file doesn't exist, create it from what
you learn this time — setup knowledge belongs in config, not in anyone's
memory. Every entry is annotated with `why` it exists, so the rationale
survives even when nobody remembers it:

```json
{
  "copy": [
    {"path": ".dev.vars", "required": true,
     "why": "Local secrets incl. AI gateway settings. Missing it does not error - every model call silently goes direct to the vendor."},
    {"path": ".env", "required": false, "why": "Present in main; gitignored."}
  ],
  "symlink": [],
  "postCreate": [
    {"run": "pnpm install",
     "why": "node_modules is per-worktree. Not symlinked: a branch may change package.json or the lockfile."}
  ],
  "baseline": [
    {"run": "pnpm test:unit", "why": "~5s. Capture the count before touching anything."}
  ],
  "preDelete": [
    {"run": "git status --porcelain",
     "why": "Uncommitted work is committed to the branch first, never discarded."},
    {"check": "look for .data/*.db",
     "why": "A local database with no git history. Snapshot it into .data/backups/ before removing."}
  ]
}
```

Keys are top-level and all optional: `copy`, `symlink`, `postCreate`,
`preDelete`, `baseline`. Each entry is either an object (`why` optional but
encouraged) or a bare string shorthand (`"npm ci"` instead of
`{"run": "npm ci"}`). A `run` entry is a shell command `se` executes; a
`check` entry is prose for a human — `se` prints it, never runs it.

- `copy` — untracked files the worktree needs (env files, local certs),
  copied from the main checkout. `required: true` makes `se env` fail
  instead of merely reporting when the file is missing from main.
- `symlink` — heavy directories shared by symlink instead of reinstalling
  (big speed win for parallel worktrees). **Caveat:** only share a
  directory like `node_modules` when branches don't change dependency
  versions; when in doubt, leave it out and let `postCreate` install fresh.
- `postCreate` — commands run inside the new worktree (installs, codegen,
  DB migrations for this worktree's own database).
- `preDelete` — commands (or manual `check` prompts) run before teardown
  (stop this worktree's containers and dev servers; flag anything a human
  should look at first).
- `baseline` — see step 3.

Run **`se env`** (idempotent, `se help` lists what it does), then apply the
isolation rules below — `docs/architecture/dev-environment.md` is the prose
companion:

- **Exclusivity**: this worktree's dev server, test runner, and data stores
  must be runnable while other worktrees run theirs. Unique ports, separate
  database files/schemas, separate cache dirs — derived from the branch name
  or set in the worktree's own env file.
- If the repo hardcodes a port, DB path, or similar shared resource, that's
  a real obstacle to parallel development: propose making it env-configurable
  as a small, separate change.
- Learned something the config or `dev-environment.md` doesn't capture?
  Write it down now, so the next worktree is cheaper.

Hand the user the parallel-session one-liner when setup is done:
`cd .claude/worktrees/<name> && claude`.

**Resuming tomorrow:** sessions persist on disk per directory, so nothing is
lost by shutting down. `se` (from any checkout) shows every worktree's TODO
progress and its `claude --continue` resume command — including for
`EnterWorktree`-started sessions, which it re-homes to the worktree's own
directory.

## 3. Capture the baseline

Immediately after setup, **before any code changes**:

- Decide this repo's test/lint/build commands once, and write them into
  `worktree.json`'s `baseline` list — that's the judgment call; every
  worktree after this one reuses it for free.
- Run **`se baseline`**. It records PASS/FAIL, duration, and an output tail
  per command to `scratchpad/baseline.md`. Pre-existing failures belong to
  main, not to this feature — note them, don't fix them (surgical changes),
  and mention them to the user.
- From now on, "done" means: the suite re-run shows **no new failures
  versus this baseline**, and the feature's own tests pass.

## 4. Start the plan

Create `docs/plan/<branch-name>.md` using the plan skill. One plan file per
worktree — that is all `docs/plan/` ever contains. The plan ends with its
`## TODO` checklist; **implementation starts only after the checklist
exists and the user has approved the plan** — the checklist existing is not
the approval. Items get checked off as steps complete.

## 5. Finish and tear down safely

Merge to main only via the PR workflow (`pr` skill). Teardown destroys a
directory, so it is its own stage gate: say the merge landed and what you
are about to remove, then **wait for the user's go-ahead**. Then delete the
worktree — safely, in this order:

1. Confirm the merge actually landed: the branch appears in
   `git branch --merged main`.
2. Tick the final TODO items in `docs/plan/<branch-name>.md`; the merged
   plan file stays as the record of what was built.
3. If the session is currently *inside* the worktree (it got there via
   `EnterWorktree`), use `ExitWorktree` with `action: "remove"` — its
   refusal when uncommitted work remains is the safety; never pass
   `discard_changes: true` without the user's explicit say-so (use
   `action: "keep"` to step out without deleting). It runs `preDelete`,
   removes the worktree, and deletes the branch itself.
4. Otherwise, run **`se teardown <name>`**. It refuses — never `--force` —
   when the worktree is dirty, unmerged, the caller is inside it, or a
   `copy`-declared file or other gitignored file unique to this worktree
   would be lost; read what it reports rather than second-guessing it. If
   it finds something real left uncommitted: never discard it silently —
   commit it to the feature branch as an explicit WIP commit or stash it,
   and tell the user what you found and where you put it. Once clean, it
   runs the `preDelete` hooks, removes the worktree, deletes the branch,
   and prunes.

Anything precious and gitignored (a local secret, a local `*.db` snapshot)
belongs in `worktree.json`'s `copy` list, not just in a comment or your
memory — that's what makes `se teardown`'s refusal mechanical instead of
hoping someone remembers to check first.
