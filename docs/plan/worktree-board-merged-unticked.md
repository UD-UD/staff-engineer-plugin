# Board: flag a merged branch whose plan still has unticked items

## Problem

When a branch is merged, `se status` always prints "merged into main but
worktree still exists, run `se teardown`". It never looks at the plan's
open count, even though it computed it on the same loop iteration. So a
branch that merged with three `- [ ]` items left reads exactly like one
whose checklist is finished, and the NEXT STEP column confidently points at
work that may already have shipped. That state means one of two things,
both worth a human's eye: the checklist is lying (work done, never ticked)
or something really did ship unfinished. Feedback item 5 from the
2026-09-20 triage.

## Approach

Chosen: one extra anomaly line, red, in `cmd_status`, when
`is_branch_merged` holds and the plan has open items. The existing teardown
recommendation stays, because `se teardown` accepts this branch today and
the board must never disagree with the tool. Nothing about the gate
changes.

Considered and rejected:
- Make the board withhold the teardown recommendation until the plan is
  ticked. Cleaner message, but the board would then refuse to recommend
  what the tool accepts, and the fix for a lying checklist is to tick it,
  not to block the teardown.
- Make `se teardown` refuse on unticked items. Changes the safety contract
  of a gate that was just settled in PR #12; out of scope for a
  board-truthfulness fix.

## Files touched

- `bin/se`: initialise `open_n=0` alongside `todo="-"` so it is defined
  under `set -u` when there is no plan; add the anomaly line inside the
  `is_branch_merged` arm; colour it red in the anomaly printer.
- `tests/test-se.sh`: a new fixture branch with a one-open-item plan,
  merged with `--no-ff`, asserting the line appears; a second, fully ticked
  fixture (`feat-q`) as the control that must not get it. Built fresh
  rather than reusing `feat-m`, whose worktree the teardown test above has
  already removed by then.
- `skills/status/SKILL.md`: one bullet under the anomaly list telling the
  model what to do with the new line (check the plan against the merge,
  tick or report, never tear down first).
- `docs/architecture/worktree.json`: new, the plugin repo's own baseline
  config (`bash tests/run.sh`). Created because the worktree skill requires
  a baseline and this repo had no config for `se baseline` to run.

## Non-goals

- No change to `safe_to_teardown` or any teardown gate.
- No change to the NEXT STEP column.
- Items 3, 1, 8, 7, 2 and 4 from the triage each get their own worktree.

## Risks

- Low. The line only fires on a merged branch with a plan that has open
  items. A merged branch with no plan file already gets the "no plan file"
  anomaly and is untouched.

## Steps

1. Test first: fixture `feat-p` in `tests/test-se.sh` with a plan holding
   one ticked and one open item, committed and merged `--no-ff`. Assert
   the board prints `feat-p — MERGED with 1 unticked plan item`. Assert the
   `feat-q` board output does not contain `unticked`. Run: red for the
   right reason.
2. `bin/se`: `open_n=0` default; the anomaly line; red colour case. Run:
   green, and the full suite still 157 + new.
3. `skills/status/SKILL.md`: the anomaly bullet.
4. `docs/decisions.md`: entry, newest first, for "board flags merged with
   unticked items, teardown gate unchanged".

## TODO

Wave 1:
- [x] 1. failing test for the new anomaly line   → verify: red, message absent
- [x] 2. bin/se anomaly line + red colour        → verify: tests/run.sh green
Wave 2:
- [x] 3. status skill anomaly bullet             → verify: bullet reads correctly
- [x] 4. decisions.md entry                      → verify: newest first
