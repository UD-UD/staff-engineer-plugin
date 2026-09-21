# Decisions

Newest first. Each entry: what was decided, what was rejected, and why.

## 2026-09-21 — Adopt select ideas from the mattpocock/skills review, reject the rest

**Decided.** Extend what already exists rather than restructure, and add
three small skills for the ideas with no existing home. The interview
technique lands as `grill` (model-invoked, called by `plan` and `setup`);
the six-phase debugging loop lands as `debug`, backed by a new git-guard
rule that refuses a commit while a `[DEBUG-xxxx]` tag survives in the
tree; a user-invoked `retro` skill proposes deterministic outlets (a
guard rule, an `se` verb, or a test) over prose. `plan` gains a `grill`
call, a `docs/decisions.md`/glossary lookup, and expand → migrate →
contract for wide refactors; `test` gains three named anti-patterns
(tautological, side-channel verification, horizontal slicing); `review`
and `staff-reviewer` gain a separate plan-conformance block; `setup` gains
a `docs/architecture/glossary.md` template and becomes user-invoked;
`worktree`, `commit`, `pr`, and `status` each gain a "Done when" line per
step; `PRINCIPLES.md` prohibitions are paired with their positive target
where one was missing. `tests/test-manifest.sh` checks the plugin
manifest and frontmatter invariants mechanically instead of running
`claude plugin validate` in CI.

**Rejected — one large "method" skill holding grilling, debugging, and
test rules.** Fewer files, but it would be always-loaded as one
description and fire for the wrong moments; Pocock's own two-loads
argument applies — split by the trigger word actually used.

**Rejected — inlining the interview into `plan` only.** Cheaper, but
`setup`'s adoption audit needs the same rounds, and a 25-line primitive is
the right size to share.

**Rejected — running `claude plugin validate` in CI.** Needs the CLI
installed on the runner and the marketplace manifest moved aside (a known
quirk). A bash manifest test in the existing suite checks the same
invariants with no new dependency, and can assert it fails on a broken
fixture.

**Rejected — a `se debug` verb listing tags.** The guard's refusal message
already names the files; nothing to add.

**Rejected — rewriting `PRINCIPLES.md` wholesale for positive phrasing.**
The file is load-bearing and injected every session; pair each
prohibition with its positive target where one is missing, leave the
rest.

**Rejected — out of scope for this branch.** An issue-tracker
abstraction, spec/ticket skills, or a wayfinder skill; any change to the
`se` CLI verbs, `safe_to_teardown`, or an existing guard rule; a
same-session review step or an auto-commit anywhere; a Fowler smell list
in the reviewer; any CI change beyond what the new test file adds through
the existing glob; a rewrite of `PRINCIPLES.md`'s structure or numbering;
a glossary written for this repo (the template lives in `setup`; this
repo gets one only if a later change needs it).

All three gates hold: hard to reverse (a new skill surface and guard rule
ship to every consumer of the plugin), surprising without context (a
merged "method" skill or a CI-based `validate` check looks simpler until
you hit always-loaded cost and runner dependencies), and a real trade-off
(fewer files vs. firing on the wrong trigger; CI enforcement vs. a
portable bash test).

## 2026-09-20 — The board flags a merged branch whose plan has unticked items

**Decided.** `se status` adds a red anomaly line, "MERGED with N unticked
plan item(s)", when a branch is merged and its plan still has open
checkboxes. The existing teardown recommendation stays beside it, and no
teardown gate changes. The line exists because the board's NEXT STEP column
was confidently pointing at work that had already shipped: a merged branch
with a lying checklist looked exactly like one with a finished plan.

**Rejected — withholding the teardown recommendation until the plan is
ticked.** Cleaner to read, but the board would then refuse to recommend what
`se teardown` accepts, and PR #12 settled that the two never disagree. The
fix for a lying checklist is to tick it.

**Rejected — making `se teardown` refuse on unticked items.** That changes
the safety contract of a gate that was just settled, for a problem that is
about the record being truthful, not about losing files.

## 2026-09-20 — The plugin repo runs its own baseline

**Decided.** `docs/architecture/worktree.json` exists here with one
baseline entry, `bash tests/run.sh`. The worktree skill requires a baseline
the moment a worktree is created, and this repo had nothing for
`se baseline` to run, so every worktree on the plugin itself started with
"no baseline entries" and the rule was being honoured by hand.

**Rejected — leaving it out because the suite is fast to run manually.**
The point of the baseline is the recorded count to compare against, not
the time saved; a rule the plugin enforces on other repos should hold on
its own.

## 2026-08-30 — Sessions are filed under the worktree they worked in

**Decided.** `se status` attributes a session to a checkout by reading the
`worktree-state` records Claude Code writes into the transcript, taking the
last non-null one. The resume list groups sessions under the checkout they
belong to, three per checkout, and joining a row runs
`claude --resume <id>` in that checkout's directory.

**Rejected — deciding from which project folder stores the transcript.** This
was the previous behaviour and the previous fix. Claude Code writes a
transcript into the folder for the directory the session was launched from and
never moves or copies it, so the folder says where a session started, not
where it worked.

**Rejected — detecting a move by finding one session id in two project
folders** (commit `b9de258`). The duplicate it looked for does not exist: 0 of
49 transcripts on this machine appear in more than one folder. Its tests
created the duplicate by hand and so passed against a world that does not
exist. Removed.

**Rejected — reading only the session's final state.** Measured: 9 of 10
worktree sessions leave the worktree before ending, so the final record is
null and would file the session back under the checkout it started in — the
original bug, reached by a new route.

**Rejected — one row per checkout with a "was in <worktree>" note.** Smaller,
but leaves the session under the base checkout and resumes onto it. Labels the
confusion instead of removing it.

**Rejected — a flat, time-ordered list of sessions.** Puts sessions in the
right place but sorts purely by time. Measured on a real repo, 5 of the 7 top
rows were the base checkout and 4 were untitled, burying the worktrees on a
board whose purpose is keeping worktrees visible.

**Rejected — a `SessionEnd` hook writing session id and worktree path to a
local file.** There is no worktree-enter hook, so exit is the only write
point, and most sessions have already left the worktree by then. It would only
work going forward, would not fire on crash or reboot — breaking se's "correct
after a reboot" contract — and would duplicate a fact Claude Code already
writes at both enter and leave.

**Rejected — printing `claude --worktree <name> --resume <id>` instead of
`cd <path> && claude --resume <id>`.** The flag does work, and does more:
tested, it reuses an existing worktree rather than creating a second one, even
when the branch breaks the `worktree-<name>` convention, and it registers
worktree-session state so `/exit` offers to keep or remove the worktree.
`cd` only puts you in the directory.

It was still rejected, because `se` has to print one command that works for
every row. The flag takes a *name*, not a path, so se would have to invent the
path→name mapping — the checkout directory `fix+mobile-keyboard-and-touch`
against a recorded worktreeName of `fix/mobile-keyboard-and-touch` — and it
has nothing to say for the base checkout or for worktrees outside
`.claude/worktrees/`. It must also be run from the main checkout. `cd <path>`
is exact for all of them, and was verified to land the resumed session in that
directory.

The probe also produced, unplanned, the exact case this change exists for:
resuming with `--worktree odd` moved the session into the `odd` worktree but
kept appending to the project folder of the worktree it previously lived in.
se filed it under `odd`, marked "started from probe", from the worktree-state
record alone.

**Constants, from measurement.** 8 newest transcripts read per project folder
(~57ms) rather than all of them (~620ms); 3 sessions shown per checkout. A
session older than a folder's 8 newest is not offered.

**Verified, not assumed.** `claude --resume <id>` resolves a session filed
under a different project folder, and the resumed session adopts the directory
it is launched in rather than re-rooting to where it started. Both were
checked by probe before the design relied on them.

**Also.** The transcript count left the last table column: with sessions moving
between groups a folder-based count contradicts the list beside it, and a count
bounded by the read depth would understate. `--continue` left every printed
command, because a row's session is not necessarily the newest transcript in
the directory it launches in.

## 2026-08-30 — `se env` creates the scratchpad sandbox

**Decided.** `se env` creates `scratchpad/` before it looks for
`worktree.json`, and warns when the directory is not gitignored.

**Why.** `scratchpad/` is gitignored, so git never carries it into a new
worktree, and nothing created it deliberately: `se:setup` does it once per
repo, and `se baseline` only as a side effect of writing its report. A
worktree that never ran a baseline had no in-tree sandbox, so agents wrote
intermediate files to `/tmp` instead — which is what happened while building
this branch. `se env` already runs for every new worktree and means "set up
this checkout", so it is the natural home.

**Rejected — telling the worktree skill to create it.** Creating a directory
is mechanical, and mechanical work belongs in the script, where it always
happens, rather than in prose an agent may or may not follow.

**Also.** The help text now derives its own end instead of using a hardcoded
line range, which truncated the output twice while writing this branch —
silently, because it simply prints fewer lines.

## 2026-08-30 — Plan filenames flatten the branch name

**Decided.** The plan file is `docs/plan/<branch>.md` with every character
outside `[A-Za-z0-9._-]` replaced by `-`. `se` looks for the exact branch name
first and the flattened form second, then falls back to "there is exactly one
plan here".

**Why.** Claude Code's own worktrees turn `fix/mobile-keyboard-and-touch` into
branch `worktree-fix+mobile-keyboard-and-touch`, and the plan was written with
the `+` flattened. Looking only for the exact name reported "no plan file" for
a worktree whose plan was sitting right there, with blank TODO progress and a
false anomaly. The rule is now stated in the plan and worktree skills so the
writer and the reader agree.
