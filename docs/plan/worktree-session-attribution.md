# worktree-session-attribution

File sessions under the worktree they worked in, and make the resume list a
grouped, session-level list.

Baseline captured at worktree creation: `bash tests/run.sh` → pass=124 fail=0.

## Problem

Four faults, all visible in one `se status` run:

1. **Attribution.** A session that starts in the repo root and enters a
   worktree is reported against the base checkout. `se` decides ownership from
   *which project folder stores the transcript*, but Claude Code writes the
   transcript into the folder for the directory the session was **launched**
   from and never moves or copies it. The move is recorded inline instead, as
   `{"type":"worktree-state","worktreeSession":{...}|null}`.
2. **One session per checkout.** The resume list shows only the newest
   transcript per project folder, so any older session is unreachable.
3. **Two naming schemes.** The branch table keys rows by branch; the resume
   menu keys them by directory basename (`bin/se:396,405,410`). No shared key.
4. **Plan lookup.** `bin/se:368` builds the plan filename with `tr '/' '-'`
   only. Native worktree branches contain `+`, so the lookup misses a plan
   that exists and raises a false anomaly.

### Why the previous attempt failed

`b9de258` assumed entering a worktree writes a *second* transcript under the
worktree and detected moves by finding one session id in two project folders.
That never happens. Its tests fabricated the duplicate by hand, so they passed
against a model of the world that does not exist. Measured: **0 of 49
transcripts on this machine appear in more than one project folder.**

## Approach

Group the resume list by checkout; list each checkout's recent sessions
beneath its heading. Attribute a session to the worktree it *worked in* (last
non-null `worktree-state`), not the folder that stores it. Resume by session
id, in the attributed checkout's directory.

```
Resume (most recent first):
  worktree-fix+mobile-keyboard-and-touch
    1   55m  (untitled)
    2    1h  Mobile experience broken     started from fancy-chat
  docs/phase-2-harness-tuning
    3    2h  (untitled)
  main
    4    2h  (untitled)
```

Picking 2 → `cd <worktree> && claude --resume 43abf2ae-...`

### Alternatives rejected

- **Label-only (keep one row per checkout, annotate `was in <wt>`).** Smaller,
  but leaves the session under `main` and resumes onto `main`. Rejected: it
  labels the confusion instead of removing it.
- **Flat session list, newest first, repo-wide.** Puts the session in the
  right place but sorts purely by time; measured against real data, 5 of 7
  top rows are `main` and 4 are untitled, burying worktrees on a board whose
  purpose is keeping worktrees visible.
- **`SessionEnd` hook writing session id + worktree path to a local file.**
  Rejected on four grounds: there is no worktree-enter hook, so exit is the
  only write point — and 9 of 10 worktree sessions end *outside* the worktree,
  so the record would say `main`; it only works going forward (49 existing
  transcripts have none); `SessionEnd` does not fire on crash/kill/reboot,
  breaking se's "correct after a reboot" contract; and it duplicates a fact
  Claude Code already writes at both enter and leave.

### Decisions taken against the approved mock-up

- Group heading carries the branch name only — git state is already in the
  table directly above it.
- No `+N older` counter: any number would be either stale (folder-based, now
  that sessions move between groups) or truncated (read-depth-based). The cap
  goes in `se help` instead.
- **All** resumes become `claude --resume <id>`; `--continue` is gone. One code
  path, and it names the conversation exactly rather than trusting file order.

## Constants, from measurement

| Constant | Value | Evidence |
|---|---|---|
| Transcripts read per project folder | 8 | 8 newest = 32 MB, scans in **57 ms** |
| Sessions shown per checkout | 3 | display cap |
| (rejected) read every transcript | — | 38 files, 242 MB, **620 ms** — too slow |

A session older than the 8 newest in its folder is not offered. Real limit;
goes in `se help`.

## Implementation notes

- **bash 3.2** on this machine and on CI (`macos-latest`). No associative
  arrays, no `mapfile`. Flat parallel arrays + linear lookup, matching the
  script's existing style.
- Pre-pass (replacing the deleted `wt_moved` pass) builds, per session:
  `sess_id` (filename stem), `sess_epoch`, `sess_title`, `sess_owner`
  (checkout whose folder stores it), `sess_home` (checkout it is attributed
  to).
- `session_worktree()` greps `"type":"worktree-state"` lines (one pass; the
  matched set is tiny), takes the last non-null one, extracts `worktreePath`.
- Attribution maps `worktreePath` to a checkout index by comparing both the
  literal and physically-resolved path (`/var` vs `/private/var` on macOS).
  No match — e.g. worktree torn down — falls back to `sess_owner`.
- Table's last column shows each checkout's newest **attributed** session, so
  table and list agree. The transcript count `(N)` is dropped.
- Tests reuse the suite's existing pty harness and fake `claude` on PATH,
  which logs `args:` and `cwd:` (`tests/test-se.sh:505+`).

## Risks

- **Unverified:** whether a session resumed by id adopts the directory we
  launch it in, or re-roots to where it started. Step 8 checks this by hand
  before any commit. If it re-roots, the list is still correct and the right
  conversation still opens; only the landing directory is wrong.
- **Visible changes:** the `(N)` transcript count leaves the table; `--continue`
  leaves every printed command. Four existing picker assertions change.
- **Removal:** deleting the two-copies detection means a future Claude Code
  that really did duplicate transcripts would bring the double-row bug back.
  Evidence against: 0 duplicates in 49 transcripts.

## Non-goals

- No change to `session_dir()` — its strict-then-loose lookup works and is
  covered.
- No caching layer; the measurement says it is unnecessary.
- No surfacing of sessions older than the read depth.
- No changes to `se env`, `baseline`, `teardown`, `debt`.
- Nothing in the `fancy-chat` repo.

## TODO

Wave 1 (parallel — disjoint files):
- [x] 1. Failing tests: worktree-state attribution fixtures, grouped output,
      `+`-in-branch plan file, picker `--resume <id>` + landing directory
      → verify: `tests/run.sh` red, each failure names the missing behaviour
      — 16 assertions added, 15 red for the intended reasons; also updated
        the 3 resume-indent assertions, the 4 picker assertions and the
        `launched()` helper, which all encoded the old flat/`--continue` shape
- [x] 2. Plan filename lookup: exact, then flattened, then single-candidate
      → verify: plan-filename test green, false anomaly gone
      — all 3 plan assertions green; `bin/se` flattens with
        `sed 's/[^A-Za-z0-9._-]/-/g'` only after the exact name misses

Wave 2 (all `bin/se`, strictly in order):
- [ ] 3. Delete the two-copies pre-pass, the "moved to" row, orphaned vars,
      and the test block encoding the wrong model
      → verify: no `wt_moved` remains; suite no worse than after step 1
- [ ] 4. `session_worktree()` + gathering pre-pass (8 newest per folder)
      → verify: attribution tests pass, incl. torn-down and path-form cases
- [ ] 5. Regroup the resume output: headings, cap 3, continuous numbering,
      "started from …" only when owner ≠ home, fresh-start rows
      → verify: grouped-output tests pass in both output formats
- [ ] 6. Carry session ids into `resume_launch`; switch to `--resume <id>`
      → verify: pty tests show `args:--resume <id>` and the right `cwd:`
- [ ] 7. Table last column = newest attributed session; drop `(N)`
      → verify: full suite green

Wave 3:
- [ ] 8. Manual run in `fancy-chat`; resolve the open resume-directory risk
      → verify: mobile session sits under its worktree; resume lands there
- [ ] 9. `se help` gains read depth + cap; plan filename rule into
      `skills/plan` and `skills/worktree`; decision into `docs/decisions.md`
      → verify: help states both constants; rule matches what the code accepts
