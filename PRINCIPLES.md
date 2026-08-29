# Core Engineering Principles

These apply to every task in this session. They are not suggestions.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No abstractions for single-use code.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- A deliberate simplification that cuts a real corner with a known ceiling
  gets a `se-debt: <ceiling>, <upgrade trigger>` comment.

Before writing code, stop at the FIRST rung that holds
(ladder adapted from ponytail, MIT):
1. Does this need to exist at all? Speculative need = skip it, say so. (YAGNI)
2. Already in this codebase? Reuse it — look before you write; re-implementing
   what lives a few files over is the most common slop.
3. Standard library does it? Use it.
4. Native platform feature covers it? Use it.
5. An already-installed dependency solves it? Use it — never add a new one
   for what a few lines can do.
6. Can it be one line? One line.
7. Only then: the minimum code that works.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Before implementation starts, turn the approved plan into a `## TODO`
checklist in `docs/plan/<branch>.md`, and tick items off as each step
completes — the checklist is the live state of the work.

Execute in parallel where the plan allows: independent steps (disjoint
files) go to Sonnet `builder` agents concurrently, wave by wave; the main
session orchestrates — it verifies each result, ticks the TODO, and commits.

## 5. SOLID by Default

**Always adhere to SOLID principles. Deviations require explicit approval.**

- Single responsibility, open/closed, Liskov substitution, interface
  segregation, dependency inversion — these are the default design posture.
- If you feel strongly that SOLID adherence is wrong for a specific case
  (e.g. it collides with Simplicity First — an interface for a single
  implementation), do NOT deviate silently: explain why and ask for the
  user's explicit approval first.
- An approved deviation leaves the same `se-debt: <ceiling>, <upgrade
  trigger>` marker, so the approval isn't lost in a chat transcript —
  `se debt` (terminal) lists the ledger.

## 6. Tests Are the Holy Grail

**Never write weak tests. Never weaken existing tests to make things work.**

- A test must be able to fail: assert specific outcomes, not just
  "it didn't crash".
- Never broaden assertions, skip, delete, or over-mock a test to get green.
  When a test fails, fix the code.

## 7. No Agent Authorship in Commits or PRs

**Git history belongs to humans — commit messages and PRs alike.**

- Never add `Co-Authored-By: Claude`, `Claude-Session:` trailers,
  "Generated with Claude Code" footers, session links, or any other AI
  attribution to commit messages, PR titles, or PR bodies — even when tool
  defaults suggest it.

## 8. Project Organization

**Self-contained projects. Main is untouched.**

- Standard layout: `scratchpad/` (gitignored agent sandbox for intermediate
  files and scripts), `docs/architecture/` (the complete project overview:
  data flow, control flow, architecture mappings), `docs/decisions.md`
  (reverse-chronological decision log), `docs/plan/` (implementation plans,
  exactly one per worktree).
- Root `CLAUDE.md` is a thin shim that routes into `docs/` — keep it updated,
  never let it grow into a manual.
- Every feature starts in a new worktree off main; never commit to main.
  Worktrees live inside the repo at `.claude/worktrees/<name>` — use Claude
  Code's native mechanism (`EnterWorktree` / `claude --worktree`) when
  available. Capture a test baseline the moment a worktree is created. After
  the work merges, remove the worktree safely — never with `--force`.

## 9. Write Respected Code

**Write code that other agents and humans alike respect.**

- Clear names, existing conventions, self-explanatory structure — the next
  reader (human or agent) should understand it without you there to explain.
- If the code needs a comment to explain *what* it does, rewrite the code;
  comments are for *why*.

## 10. Quiet Execution

**Output tokens are money. Mechanics are quiet; judgment is loud.**

- Between tool calls: at most one short status line, and only when
  direction changes or something load-bearing surfaced.
- Never restate what tool output already shows.
- Don't narrate the obvious next step.
- Final message: outcome, evidence, next action — compact. Long-form
  explanation belongs in the explainer's artifact page, not the chat.
- Never economize on judgment: assumptions, pushback, blockers, and
  findings always surface (Principle 1 wins).
