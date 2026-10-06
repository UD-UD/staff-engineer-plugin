---
name: pr
description: Pull request - "open a PR", the branch is "ready for review", or any PR preparation. Self-reviews the full branch diff first, then writes a why-focused description with verification steps, risk callouts, and reviewer guidance.
---

# Pull Request Preparation

A PR is a request for a colleague's time. The author's job is to make review
fast: explain why, surface the risk, and arrive pre-reviewed.

## Process

### 1. Self-review first

Review the **full branch diff against the base branch**
(`git diff <base>...HEAD`), not just the last commit — use the plugin's
`review` skill / staff-reviewer agent for this. Fix blockers before opening
the PR. A PR opened with known defects wastes the reviewer's pass.

**Done when:** the reviewer's report is in hand and every Blocker is fixed.

### 2. Sanity-check the branch

- All tests pass locally; state which suite you ran.
- No leftover debug output, commented-out code, or unrelated formatting churn
  in the diff.
- Commits tell a readable story; squash pure fixup noise if the project's
  workflow allows it.

**Done when:** tests pass, the diff is clean, and the commit history reads
well.

### 3. Offer a sin check

Offer an adversarial pass in one line: "Want me to check this branch for
sins before the PR?" On yes, call the Skill tool with `"check-sins"` in
change mode. Sins the user chooses to act on are fixed (back to step 1 for
the new commits); sins accepted as risk are carried into the Risk section —
including any already in the plan file's `## Accepted risks` from an
earlier run. Any plan-file edit this step makes is committed before moving
on, so step 2's clean-diff check still holds.

**Done when:** the user has skipped it, or every sin has the user's decision.

### 4. Write the description

Title: conventional-commit style, imperative, specific.

Body structure:

```
## What
One paragraph: the change at the level a reviewer needs.

## Why
The problem or goal driving it. Link the issue/ticket if one exists.

## How to verify
Exact steps or commands a reviewer can run to see it working.

## Risk
What could break, what to watch after merge, any rollback note.
Migrations, config changes, and compat concerns go here explicitly.
Sins accepted as risk (step 3, or the plan file's `## Accepted risks`) are
named here.
```

Include screenshots or before/after output for anything user-visible.

**No AI attribution anywhere in the PR**: no "Generated with Claude Code"
footers, no session links, no co-author credits — even when tool defaults
append them. The PR is authored by the user alone.

**Done when:** the body has What, Why, How to verify, and Risk, with no AI
attribution.

### 5. Guide the reviewer

Name the one or two files where the real decision lives and what kind of
scrutiny you want ("the retry logic in `sync.ts` is the risky part"). If a
change is large but mechanical, say which parts are mechanical so the
reviewer can skim them.

**Done when:** the reviewer knows where to look first and what to skim.

### 6. Open it

Opening a PR is outward-facing and is its own stage gate: show the title and
body, and **wait for the user's go-ahead** before creating it. Then use the
`gh` CLI when available. Target the project's default base branch unless told
otherwise. Open as a draft when the work is explicitly work-in-progress;
otherwise ready-for-review.

**Done when:** the user has said go and `gh pr view` shows the PR.
