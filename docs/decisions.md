# Decisions

Newest first. Each entry: what was decided, what was rejected, and why.

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
