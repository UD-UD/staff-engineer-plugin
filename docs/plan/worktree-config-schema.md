# worktree.json config schema

## Goal

Make `docs/architecture/worktree.json`'s canonical shape the flat,
annotated schema a real adopting repo (fancy-chat) independently converged
on — `copy`/`symlink`/`postCreate`/`preDelete`/`baseline` as top-level
lists of `{path|run|check, why, required?}` objects (bare strings still
work as shorthand) — instead of the plugin's current nested
`sync`/`hooks`/`baseline.commands` shape. Make `se env`/`se baseline`/
`se teardown` read it, fail loudly (never silently) on anything that
doesn't match, and add two new `se teardown` gates so a unique gitignored
file (a local secret, a local db snapshot) can never be deleted
unrecoverably.

## Why

Verified against a real config: every one of `se`'s five JSON lookups
misses against the annotated schema, and `se env` reports "no configured
entries" — indistinguishable from "I can't read this file". The annotated
form is strictly better (setup rationale lives in the config, not in
anyone's memory), so the plugin adopts it as the one canonical schema —
no dual-schema support, migration is a rename. Separately, `se teardown`'s
only "anything left to save" check is `git status --porcelain`, which by
design never lists gitignored files — a worktree holding a unique
`.dev.vars` or `.data/*.db` is reported clean and destroyed unrecoverably.

## TODO

Wave 1:
- [x] `bin/se`: replace `json_list` with `wt_json_py` (single python
      helper, `shape`/`records` modes) — normalizes bare-string shorthand
      and `{path|run|check, why, required}` objects into
      `KIND\tVALUE\tWHY\tREQUIRED` rows; malformed entries (object with
      none of run/path/check) fail loudly naming file + entry index.
- [x] `bin/se` `cmd_env`: canonical `copy`/`symlink`/`postCreate` sections;
      `required:true` copy/symlink missing from main is fatal; `check:`
      entries print under "manual checks (not run):" and are never
      executed; loud old-layout / no-recognized-entries messages before
      doing anything.
- [x] `bin/se` `cmd_baseline`: canonical `baseline` section; `check:`
      entries handled the same way; failing run entries print their `why`.
- [x] `bin/se` `cmd_teardown`: canonical `preDelete` section (same
      check/why handling); two new hard-refusal gates before the existing
      preDelete hooks run — config-declared `copy` paths that differ from
      main, and unique gitignored paths (excluding rebuildable noise) not
      present in main. `se help` header updated.

Wave 2 (after wave 1 verified):
- [x] `skills/worktree/SKILL.md` §2 canonical example + why-it-belongs
      note in §5; `skills/setup/SKILL.md` wording check; `README.md`
      repo-layout line.
- [x] `tests/test-se.sh`: migrate the primary fixture to the annotated
      schema (copy+symlink+postCreate+preDelete run/check+baseline, all
      still exercising the existing assertions) and add fixtures for:
      bare-string shorthand, `required:true` missing-from-main failure,
      old-nested-layout rejection, garbage-keys rejection, check-entries
      never executed, teardown copy-gate refusal, teardown ignored-file
      gate refusal, excluded dirs (node_modules) not tripping the gate.
      `bash tests/run.sh`: 72/72 green (was 60/60 before this change).

Wrap-up:
- [x] Real-world fixture proof: paste the fancy-chat-style annotated
      config into a throwaway fixture, confirm `se env` parses it cleanly.
      copy .dev.vars: done / copy .env: missing in main (not fatal, not
      required) / postCreate ok / exit 0. $comment/root/baseBranch/notes
      silently ignored as intended.
- [x] `bash tests/run.sh` green from repo root and from a different cwd
      (72/72 both times); `claude plugin validate .` green.
- [x] Commit, push, open PR (no AI attribution anywhere).
