---
name: review
description: Use before committing, before opening a PR, or when asked to "review this", "check my changes", or "look at this diff". Runs a staff-engineer review of the working diff (or a named commit range) - correctness, error handling, silent failures, security, naming, and needless complexity - reports verified, ranked findings.
---

# Staff-Engineer Code Review

Review code the way a staff engineer reviews a teammate's PR: assume the author
is competent, hunt for what actually breaks, and stay quiet about what a
formatter or linter would catch.

## Scope

1. Default scope is the uncommitted work: `git diff` plus `git diff --staged`,
   and any untracked files that belong to the change (`git status`).
2. If the user names a branch, commit range, or PR, review that instead
   (`git diff <base>...HEAD`, or `gh pr diff <number>`).
3. If the diff is empty, say so and ask what to review — do not review the
   whole repository unprompted.

## Fresh eyes

If you wrote the code under review in this session, delegate the review to the
**staff-reviewer** agent bundled with this plugin, passing it the exact scope
(diff command or range). Reviewing your own code in the same context inherits
your own blind spots. If the agent is unavailable, review inline but re-read
each changed file from disk rather than trusting your memory of it.

## What to look for, in priority order

1. **Correctness** — logic errors, off-by-ones, broken edge cases (empty,
   null, zero, huge, concurrent), wrong assumptions about inputs.
2. **Silent failures** — swallowed exceptions, ignored return values, fallback
   values that mask real errors, catch blocks that log-and-continue where the
   operation cannot actually continue.
3. **Error handling** — missing handling on IO/network/parse boundaries;
   errors surfaced with enough context to debug.
4. **Security** — injection, unvalidated input crossing a trust boundary,
   secrets in code or logs, unsafe deserialization.
5. **Contract breaks** — changed behavior that existing callers or tests
   depend on; API/schema changes without migration.
6. **SOLID violations** — a class/module taking on a second responsibility,
   substitution-breaking subtypes, high-level code newly depending on
   concretions. Flag clear violations that will hurt maintenance, not
   textbook purity; note that intentional, user-approved deviations are fine.
7. **Weak or weakened tests** — tests in the diff that can't meaningfully
   fail (no real assertions, over-mocked to the point of testing the mock),
   and any existing test the diff loosened, skipped, or deleted to get green.
8. **Over-engineering** — abstractions with a single caller, speculative
   "flexibility" or configurability nobody asked for, error handling for
   impossible scenarios, 200 lines where 50 would do. Simplicity test: would
   a senior engineer call this overcomplicated?
9. **Non-surgical changes** — changed lines that don't trace to the change's
   stated intent: drive-by reformatting, "improved" adjacent code or comments,
   refactors of things that weren't broken. Also the reverse: orphans the
   change created (imports, variables, functions it made unused) but left
   behind.
10. **Naming and clarity** — only when a name is misleading, not merely
    imperfect. Code should be respected by its next reader, human or agent:
    if it needs a comment to explain *what* it does, that's a finding.

## Verification before reporting

Every finding must survive this test: *can you state concrete inputs or state
that produce the wrong outcome?* Read the surrounding code — callers, callees,
existing guards — before claiming a bug. Drop anything speculative. A short
list of real problems beats a long list of maybes.

## Report format

Rank findings by severity:

- **Blocker** — will break in realistic use; must fix before commit.
- **Should fix** — real defect or debt, but not release-blocking.
- **Consider** — simplification or clarity improvement; at most a few.

Each finding: `file:line`, one-sentence defect statement, the concrete failure
scenario, and a suggested fix. Compact, not narrated:

❌ "This function might have an issue with how it handles empty inputs — it
could potentially be worth considering whether a guard clause would make
this more robust."
✅ `sync.ts:142 — empty batch skips the flush guard — a consumer polling an
empty queue never commits its offset — add the length check before
early-return.`

If nothing survives verification, the entire report is one line: "No
findings survived verification. Riskiest area: <area> — <why>." An empty
review should still tell the user where you looked.

Report first; apply fixes only when the user asks.

When the report has substance (any blocker or should-fix), also delegate to
the `explainer` agent to publish it as a plain-English artifact page — each
finding stated in simple words with its real-world consequence — and share
the link. The terminal keeps the compact `file:line` version; the artifact is
the one a human reads end to end.
