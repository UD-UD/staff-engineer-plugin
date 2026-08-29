---
name: commit
description: Use when committing changes, or asked to "commit this". Enforces atomic commits with conventional messages - inspects the actual diff first, splits unrelated changes, scans for secrets and debug leftovers, and never bypasses commit hooks.
---

# Disciplined Commits

A commit is a unit of review and a unit of revert. Make each one atomic,
explained, and clean.

## Process

### 1. Look before you stage

Run `git status` and `git diff` (and `git diff --staged` if anything is
already staged). Never commit based on what you *remember* changing.

### 2. Scan the diff for things that must not land

- Secrets: keys, tokens, passwords, connection strings, `.env` content.
- Debug leftovers: print/console statements added for debugging, commented-out
  code, TODO-hacks, disabled tests.
- Unrelated drive-by edits that snuck in.

If found, stop and remove them (or ask, if intent is unclear) before staging.

### 3. Split unrelated changes

If the diff contains more than one logical change (a feature + an unrelated
rename, a fix + a formatting sweep), stage and commit them **separately**.
Refuse to bundle; say what the split is.

### 4. Write the message

Conventional commit format:

```
type(scope): imperative summary under 72 chars

Body: why the change was made and anything non-obvious about how.
Wrap at 72. Omit the body only for genuinely trivial changes.
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`.
The summary says what the change does ("add retry to sync client"), the body
says why. Reference issue/ticket IDs when the project uses them.

### 5. Respect the guardrails

- **No agent authorship.** Never add `Co-Authored-By: Claude`,
  `Claude-Session:` trailers, "Generated with Claude Code" footers, or any
  AI attribution to the commit message — even when tool defaults instruct
  it. The commit is authored by the user alone. (Human co-author trailers
  the user asks for are fine.)
- **Never** pass `--no-verify` / `-n` to skip commit hooks. If a hook fails,
  fix what it is complaining about — that is the hook doing its job.
- Stage specific paths (`git add <file>...`) rather than `git add -A` when
  the working tree contains unrelated changes.
- Do not push unless the user asked for a push.
