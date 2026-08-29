# se (Staff Engineer)

A Claude Code plugin that tunes development toward staff-engineer habits:
plan before coding, review before committing, ship tests with every behavior
change, and keep git history clean.

**Status: first draft.**

## What's inside

| Component | Invoke as | What it does |
|---|---|---|
| `PRINCIPLES.md` | (always on) | Core principles injected into context at every session start: think before coding, simplicity first, surgical changes, goal-driven execution, SOLID by default, strong tests, no agent authorship in commits, standard project layout + worktree-per-feature, respected code |
| `skills/setup` | `/se:setup` | Scaffolds/audits the standard self-contained layout: `scratchpad/` sandbox, `docs/architecture/`, `docs/decisions.md`, `docs/plan/`, thin `CLAUDE.md` shim |
| `skills/worktree` | `/se:worktree` | Starts a feature: worktree off main, config-driven setup via `docs/architecture/worktree.json` (copy files, symlink heavy dirs, post-create/pre-delete hooks), isolated dev environment (exclusive ports/DBs for parallel development), test baseline in `scratchpad/baseline.md`, plan + TODO checklist in `docs/plan/`, and safe teardown after merge (merged-check, pre-delete hooks, clean-check, no `--force`) |
| `skills/plan` | `/se:plan` | Implementation plan before code: explicit assumptions, prior art, 2–3 weighed approaches, non-goals, nothing speculative, verifiable steps — saved to `docs/plan/<branch>.md` ending in a `## TODO` checklist that gates implementation and tracks live progress; decisions logged to `docs/decisions.md` |
| `skills/review` | `/se:review` | Reviews the working diff (or a range) for correctness, silent failures, security, complexity — verified findings only |
| `skills/test` | `/se:test` | Testing discipline: regression test first for bugs, right test level, never weaken a test to make it pass |
| `skills/commit` | `/se:commit` | Atomic commits, conventional messages, secret/debug-leftover scan, no `--no-verify` |
| `skills/pr` | `/se:pr` | Self-reviewed PRs with why-focused descriptions, verification steps, and risk callouts |
| `bin/se` | `se` (terminal) | Deterministic status board — zero LLM: every worktree with branch state, TODO progress from `docs/plan/`, next unchecked step, saved-session age/title/count from `~/.claude/projects/`, anomaly flags, and the exact `claude --continue` resume command per worktree. Correct after a reboot |
| `skills/status` | `/se:status` | Thin wrapper: runs `se`, relays the board verbatim, and helps act on anomalies (teardown, missing plans, relocating orphaned sessions) |
| `agents/builder` | (used during implementation) | Sonnet implementation agent: executes exactly one TODO step, test-first, within its assigned file scope — independent steps run as parallel builders (wave by wave) while the main session orchestrates, verifies, ticks the TODO, and commits |
| `agents/staff-reviewer` | (used by `review`/`pr`) | Read-only reviewer subagent — fresh eyes, reports ranked `file:line` findings, never edits |
| `agents/explainer` | (used by `plan`/`review`) | Sonnet-powered plain-English writer: turns plans, reviews, and explanations into jargon-free artifact pages and returns the link; page HTML lives in the project's `scratchpad/artifacts/` (switch to Haiku by editing `model:` in its frontmatter) |
| `hooks/git-guard` | (automatic) | `PreToolUse` hook blocking `git commit --no-verify`, plain force-pushes, `git push --no-verify`, AI-attribution trailers in commit messages, direct commits on main/master (override: `STAFF_ENGINEER_ALLOW_MAIN=1` prefix, with explicit user approval), and `git worktree remove --force` |
| SessionStart hook | (automatic) | Injects `PRINCIPLES.md` into context when a session starts, resumes, or compacts — the principles are always active, not on-demand |

Skills are also auto-invoked by the model when their `description` matches
what you're doing (e.g. asking for a review triggers `review` without the
slash command). Set `disable-model-invocation: true` in a skill's frontmatter
to make it slash-command-only.

## Install

### Try it (single session)

```bash
claude --plugin-dir /Users/dev/workshop/staff-engineer-plugin
```

### Install persistently (local marketplace)

This repo doubles as a one-plugin marketplace (`.claude-plugin/marketplace.json`).
Inside Claude Code:

```
/plugin marketplace add /Users/dev/workshop/staff-engineer-plugin
/plugin install se@ujjal-plugins
```

Or from GitHub (any machine):

```
/plugin marketplace add https://github.com/UD-UD/staff-engineer-plugin.git
/plugin install se@ujjal-plugins
```

### Validate after editing

```bash
claude plugin validate /Users/dev/workshop/staff-engineer-plugin
```

Checks manifest, hooks JSON, and all skill/agent frontmatter. Use
`/reload-plugins` in a session to pick up changes without restarting.

The `se` terminal command ships in the plugin's `bin/`, which Claude Code
adds to PATH for installed plugins. If your install mode doesn't (or to use
it outside Claude Code entirely), alias it:
`alias se='/Users/dev/workshop/staff-engineer-plugin/bin/se'`.

## Layout

```
staff-engineer-plugin/
├── .claude-plugin/
│   ├── plugin.json          # manifest
│   └── marketplace.json     # lets this repo act as a local marketplace
├── PRINCIPLES.md            # always-on principles, injected by SessionStart hook
├── bin/
│   └── se                   # deterministic status board (worktrees + sessions)
├── skills/
│   ├── setup/SKILL.md
│   ├── worktree/SKILL.md
│   ├── status/SKILL.md
│   ├── plan/SKILL.md
│   ├── review/SKILL.md
│   ├── test/SKILL.md
│   ├── commit/SKILL.md
│   └── pr/SKILL.md
├── agents/
│   ├── builder.md
│   ├── staff-reviewer.md
│   └── explainer.md
└── hooks/
    ├── hooks.json           # SessionStart → PRINCIPLES.md, PreToolUse → git-guard.sh
    └── scripts/git-guard.sh
```

## Tuning it

- **Change the always-on principles**: edit `PRINCIPLES.md` — it's injected
  verbatim at session start, so keep it short; every word costs context in
  every session.
- **Change what a skill enforces**: edit its `SKILL.md` body — it's plain
  instructions. The `description` frontmatter controls when the model
  auto-invokes it; keep it trigger-focused.
- **Add guardrails**: extend `hooks/scripts/git-guard.sh` (exit `2` + a
  stderr message blocks the tool call; exit `0` allows it).
- **Reviewer strictness**: edit `agents/staff-reviewer.md`; `model:` and
  `tools:` are set in its frontmatter.

## Credits

The config-driven worktree setup (`worktree.json` with sync + lifecycle
hooks) is adapted from
[opencode-worktree](https://github.com/kdcokenny/opencode-worktree) (MIT).

## Known first-draft limitations

- The git-guard regexes check the whole command string, so a flag inside a
  quoted string (e.g. `git commit -m "note about -n"`) can false-positive.
- Guard script requires `python3` on PATH; if missing it silently allows.
- The agent-authorship rule inspects the command string, so a message
  committed from a file (`git commit -F msg.txt`) isn't scanned — the commit
  skill's instruction is the only layer covering that path.
- The main-branch rule resolves the branch from the session's working
  directory, so a command that `cd`s into a different repo before committing
  can evade it.
- Skills are stack-agnostic by design; project-specific conventions (test
  runner, base branch name) are discovered at runtime rather than configured.
