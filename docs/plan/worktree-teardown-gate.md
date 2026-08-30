# worktree-teardown-gate

Make `se status` and `se teardown` agree about what is safe to tear down.

Baseline captured at worktree creation: `bash tests/run.sh` → pass=148 fail=0.

## Problem

The board recommends a command the tool then refuses:

```
Anomalies:
  ! worktree-ponytail-adoptions — TODO complete and branch merged → run `se teardown ponytail-adoptions`

$ se teardown ponytail-adoptions
se teardown: branch 'worktree-ponytail-adoptions' is not merged into main — refusing
```

They use different predicates:

- **status** flags on `is_branch_merged` **or** (`is_merged` and the plan's
  TODO reads "all done") — two conditions.
- **teardown** gates on `is_branch_merged` alone — one of them.

`is_branch_merged` requires the branch tip to have *left* base's first-parent
chain, which is how it avoids flagging a freshly created branch that points at
main and has no work yet. That guard is right, but it cannot tell a fresh
branch from one whose work was merged and whose tip was then moved onto the
merge commit — which is what happened to `worktree-ponytail-adoptions`
(tip `c271172` is main's own merge commit for PR #6, nothing unique on it).

## Approach

Give both callers **one shared predicate**, so they cannot disagree:

```
safe_to_teardown(branch) = is_branch_merged(branch)
                        OR (is_merged(branch) AND plan_complete(branch))
```

That is exactly the union `se status` already flags, so the invariant becomes:
**whenever the board says "run `se teardown X`", teardown accepts.**

`plan_complete` = the branch's plan file exists, has at least one ticked item,
and has no open ones. Requiring a ticked item keeps a plan with no checklist
at all from counting as complete.

### Rejected — drop `! in_mainline` from teardown's gate

My first read. `is_merged` alone is the pure "nothing would be lost" test
(`git branch --merged X` means precisely "no commits not in X"), so it looked
like the correct safety property.

It is not what teardown is for. `tests/test-se.sh:386` asserts that
`se teardown feat-x` **refuses** for a freshly created worktree with no unique
commits — removing it loses no commits but does lose the `se env` setup and,
more to the point, is almost certainly a mistake. Teardown is for finished
work, not for anything that happens to be empty. Dropping the guard would have
turned that existing assertion red, which is what caught the error.

### Rejected — reflog, or branch age

Would distinguish the two cases, but the reflog is local and absent in a fresh
clone, so the board's answer would depend on which machine it runs from. `se`
reads durable state only.

## Implementation notes

Both conditions currently live inline in `cmd_status`'s loop, and the plan
lookup is duplicated logic teardown does not have at all. Extract two helpers
next to the existing `is_merged` / `is_branch_merged`:

- `plan_file <checkout> <branch>` — exact name, then flattened, then the
  single-candidate fallback. This is the lookup already in `cmd_status`,
  lifted so teardown can use it too.
- `plan_complete <checkout> <branch>` — plan exists, ≥1 ticked, 0 open.
- `safe_to_teardown <checkout> <branch>` — the union above.

`cmd_status` keeps computing `todo` / `next` for display from `plan_file`; only
its anomaly condition switches to the shared predicate. `cmd_teardown`'s gate
switches from `is_branch_merged` to `safe_to_teardown`, and its refusal
message should say what it actually checked, so the next false negative is
diagnosable rather than mysterious.

## Non-goals

- No change to `is_branch_merged` itself, or to the status anomaly's wording.
- No change to teardown's other gates: dirty tree, config-declared copy files
  that differ, unique irreplaceable ignored files. Those are orthogonal and
  already tested.
- No new flag, and still no force.

## Risks

- **Widens what teardown accepts.** A branch that is merged with a complete
  plan can now be removed even if its tip sits on main's first-parent chain.
  That is the intended change, and every other gate still applies — dirty
  tree, differing copy files, irreplaceable ignored files.
- **Depends on plan files.** A repo that does not keep `docs/plan/` gets the
  old behaviour exactly, since `plan_complete` is then always false.

## TODO

- [x] 1. Failing tests: a merged branch whose tip is main's merge commit with
      a complete plan tears down; the same branch without a plan still
      refuses; a fresh worktree still refuses; the refusal message names what
      was checked
      → verify: `tests/run.sh` red, each failure names the missing behaviour
      — first fixture was wrong: `git branch -f` silently refuses to move a
        branch that is checked out in a worktree, so the case under test never
        existed and the assertion passed for the wrong reason. Moved the
        branch from inside its own worktree with `reset --hard` instead.
- [x] 2. Extract `plan_file` / `plan_complete` / `safe_to_teardown`; point
      `cmd_status`'s anomaly and `cmd_teardown`'s gate at the shared predicate
      → verify: full suite green, including the existing feat-x refusal
      — the single-candidate plan fallback turned out to be unsafe as a gate:
        a branch cut from a base that already carries a finished plan inherits
        it and authorises its own teardown. Split into `plan_file_named`
        (gate) and `plan_file` (display, keeps the fallback).
      — the existing "unmerged refusal names the reason" assertion expected
        "not merged" for a fresh branch that git considers merged; the message
        was inaccurate, so it now states the real reason and a new case covers
        a genuinely unmerged branch.
      — 157 pass, 0 fail (baseline 148).
- [ ] 3. Tear down `ponytail-adoptions` with the fixed tool, after merge
      → verify: it succeeds; `se` shows one worktree and no anomalies
      — pre-checked: its plan is 5 ticked / 0 open and the branch is merged,
        so the new gate admits it.
