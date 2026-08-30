#!/bin/bash
# Fixture-driven checks of every bin/se subcommand. Builds a throwaway git
# repo (+ one linked worktree) under mktemp, drives `se` against it, and
# tears the fixture down again. Never modifies bin/se; only ever runs it.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
se="$root/bin/se"

pass=0
fail=0

ok() { pass=$((pass + 1)); printf 'ok - %s\n' "$1"; }
notok() { fail=$((fail + 1)); printf 'not ok - %s\n' "$1"; }

assert_exit() { # desc expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else notok "$1 (expected exit $2, got $3)"; fi
}

assert_contains() { # desc haystack needle
  case "$2" in
    *"$3"*) ok "$1" ;;
    *) notok "$1 (missing: $3)" ;;
  esac
}

assert_not_contains() { # desc haystack needle
  case "$2" in
    *"$3"*) notok "$1 (unexpectedly present: $3)" ;;
    *) ok "$1" ;;
  esac
}

assert_true() { # desc [ test-expr result ]
  if [ "$2" = "0" ]; then ok "$1"; else notok "$1"; fi
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# --- fixture: main repo -----------------------------------------------------
main="$tmpdir/main"
mkdir -p "$main"
git -C "$main" init -q -b main
git -C "$main" config user.email test@example.com
git -C "$main" config user.name Test

printf '# fixture\n' > "$main/README.md"
{
  printf '.env\n'
  printf 'pc-ran\n'
  printf 'scratchpad/\n'
  printf 'shared-dir\n'
  printf 'node_modules/\n'
  printf '.data/\n'
} > "$main/.gitignore"

sentinel="$tmpdir/predelete-sentinel"
checkcanary="$tmpdir/check-canary-$$"
mkdir -p "$main/docs/architecture"
cat > "$main/docs/architecture/worktree.json" <<EOF
{
  "copy": [
    {"path": ".env", "required": true, "why": "local secret needed for dev"}
  ],
  "symlink": [
    {"path": "shared-dir", "why": "heavy shared dependency dir"}
  ],
  "postCreate": [
    {"run": "touch pc-ran", "why": "marks postCreate ran"}
  ],
  "preDelete": [
    {"run": "touch $sentinel", "why": "marks preDelete ran"},
    {"check": "touch $checkcanary", "why": "must never execute - prose only"}
  ],
  "baseline": [
    {"run": "true", "why": "always passes"},
    {"run": "false", "why": "always fails"}
  ]
}
EOF

git -C "$main" add -A
git -C "$main" commit -q -m init

# Untracked/gitignored content that lives only in the main checkout's
# working directory — sync sources, plus a marker main "already has" so it
# isn't mistaken for something unique to the worktree later.
echo "SECRET=1" > "$main/.env"
mkdir -p "$main/shared-dir"
echo "shared" > "$main/shared-dir/file.txt"
touch "$main/pc-ran"

# --- fixture: a worktree on a feature branch --------------------------------
mkdir -p "$main/.claude/worktrees"
feat="$main/.claude/worktrees/feat-x"
git -C "$main" worktree add -q -b feat-x "$feat" main

# ============================================================ se (status) ==
emptyhome=$(mktemp -d)
out=$(cd "$main" && HOME="$emptyhome" "$se")
rc=$?
assert_exit "se status exits 0" 0 "$rc"
assert_contains "se status prints a BRANCH header" "$out" "BRANCH"

# resume list is a numbered menu grouped under a heading per checkout, so its
# rows sit one level in. Non-interactive runs (stdin/stdout not a tty, as
# every `$(...)` capture in this suite is) never prompt.
assert_contains "se status numbers resume line 1" "$out" "    1  cd "
assert_contains "se status numbers resume line 2" "$out" "    2  cd "
assert_not_contains "se status (non-interactive) does not print the picker prompt" "$out" "Join ["

out=$(cd "$main" && HOME="$emptyhome" SE_NO_PROMPT=1 "$se")
rc=$?
assert_exit "SE_NO_PROMPT=1 se exits 0" 0 "$rc"
assert_contains "SE_NO_PROMPT=1 se numbers resume line 1" "$out" "    1  cd "
assert_not_contains "SE_NO_PROMPT=1 se does not print the picker prompt" "$out" "Join ["

rm -rf "$emptyhome"

# --- session lookup: Claude Code's path encoding flattens more than / and . -
# A worktree with a `+` in its name is stored with the `+` as `-`, so a naive
# tr '/.' '--' misses its transcripts and the board wrongly calls it fresh.
plushome=$(mktemp -d)
plusfeat="$main/.claude/worktrees/feat+plus"
git -C "$main" worktree add -q -b feat-plus "$plusfeat" main
# git reports the fully resolved path (macOS /var -> /private/var), and that
# is what se encodes, so the fixture has to use the same form.
plusreal=$(cd "$plusfeat" && pwd -P)
loose=$(printf '%s' "$plusreal" | sed 's/[^A-Za-z0-9]/-/g')
mkdir -p "$plushome/.claude/projects/$loose"
printf '{"type":"ai-title","aiTitle":"Plus named worktree"}\n{"cwd":"%s"}\n' "$plusreal" \
  > "$plushome/.claude/projects/$loose/session-a.jsonl"

out=$(cd "$main" && HOME="$plushome" SE_NO_PROMPT=1 "$se")
assert_contains "session found despite + flattened in the stored path" "$out" "Plus named worktree"
assert_not_contains "the + worktree is not reported fresh" "$out" "$plusreal && claude    # no saved session"

# Same loose directory, but its transcript's cwd points somewhere else: the
# looser match must not be trusted, or two similarly-named worktrees would
# borrow each other's sessions.
printf '{"type":"ai-title","aiTitle":"Someone elses session"}\n{"cwd":"/somewhere/else"}\n' \
  > "$plushome/.claude/projects/$loose/session-a.jsonl"
out=$(cd "$main" && HOME="$plushome" SE_NO_PROMPT=1 "$se")
assert_not_contains "loose match rejected when the transcript cwd disagrees" "$out" "Someone elses session"

git -C "$main" worktree remove "$plusfeat"
git -C "$main" branch -D feat-plus >/dev/null 2>&1
rm -rf "$plushome"

# --- attribution: the folder holding a transcript is not where the work was -
# Claude Code stores a session's transcript in the project folder for the
# directory it was LAUNCHED from and never moves or copies it. Entering a
# worktree is recorded inline instead, as a `worktree-state` line naming the
# worktree; leaving writes the same record with a null payload. So a session
# filed under the main checkout may have done all its work in a worktree, and
# the board has to say so — and resume it there.
atthome=$(mktemp -d)
mainreal=$(cd "$main" && pwd -P)
featreal=$(cd "$feat" && pwd -P)
attmain="$atthome/.claude/projects/$(printf '%s' "$mainreal" | tr '/.' '--')"
attfeat="$atthome/.claude/projects/$(printf '%s' "$featreal" | tr '/.' '--')"
mkdir -p "$attmain" "$attfeat"

# Launched from main, entered the worktree, and left again before ending —
# the common shape: 9 of 10 real worktree sessions end back outside. The last
# NON-NULL record is what says where the work happened.
{
  printf '{"type":"ai-title","aiTitle":"Mobile work"}\n'
  printf '{"cwd":"%s"}\n' "$mainreal"
  printf '{"type":"worktree-state","sessionId":"sess-mobile","worktreeSession":{"originalCwd":"%s","worktreePath":"%s","worktreeName":"feat/x","worktreeBranch":"feat-x","originalBranch":"main"}}\n' "$mainreal" "$featreal"
  printf '{"cwd":"%s"}\n' "$featreal"
  printf '{"type":"worktree-state","sessionId":"sess-mobile","worktreeSession":null}\n'
} > "$attmain/sess-mobile.jsonl"

printf '{"type":"ai-title","aiTitle":"Plain main work"}\n{"cwd":"%s"}\n' "$mainreal" \
  > "$attmain/sess-plain.jsonl"
printf '{"type":"ai-title","aiTitle":"Own worktree session"}\n{"cwd":"%s"}\n' "$featreal" \
  > "$attfeat/sess-own.jsonl"

touch -t 202601030000 "$attfeat/sess-own.jsonl"
touch -t 202601020000 "$attmain/sess-mobile.jsonl"
touch -t 202601010000 "$attmain/sess-plain.jsonl"

out=$(cd "$main" && HOME="$atthome" SE_NO_PROMPT=1 "$se")

assert_contains "a session that entered a worktree resumes there, by id" \
  "$out" "cd $featreal && claude --resume sess-mobile"
assert_not_contains "it is not offered from the directory it was launched in" \
  "$out" "cd $mainreal && claude --resume sess-mobile"
assert_contains "the worktree's own session is still listed" \
  "$out" "cd $featreal && claude --resume sess-own"
assert_contains "a session that never left stays with its own checkout" \
  "$out" "cd $mainreal && claude --resume sess-plain"
assert_contains "the moved session says which checkout it started from" \
  "$out" "started from $(basename "$mainreal")"
assert_contains "resume rows are grouped under a heading naming the branch" \
  "$out" "$(printf '\n  feat-x\n')"
assert_contains "the base checkout gets its own group heading" \
  "$out" "$(printf '\n  main\n')"
# One code path for every resume: name the conversation, never trust file order.
assert_not_contains "resume no longer relies on --continue" "$out" "claude --continue"

# At most three sessions per checkout, newest first: a fourth is not offered.
for s in ancient older newer; do
  printf '{"type":"ai-title","aiTitle":"Filler %s"}\n{"cwd":"%s"}\n' "$s" "$mainreal" \
    > "$attmain/sess-$s.jsonl"
done
touch -t 202512310000 "$attmain/sess-ancient.jsonl"
touch -t 202601010100 "$attmain/sess-older.jsonl"
touch -t 202601010200 "$attmain/sess-newer.jsonl"
out=$(cd "$main" && HOME="$atthome" SE_NO_PROMPT=1 "$se")
assert_contains "the checkout's three newest sessions are offered" "$out" "sess-newer"
assert_not_contains "a fourth, older session is not offered" "$out" "sess-ancient"

# A worktree that has been torn down since the session ran: the recorded
# worktreePath matches no checkout, so the session falls back to the folder
# that stores it rather than vanishing from the board.
printf '{"type":"ai-title","aiTitle":"Gone worktree"}\n{"cwd":"%s"}\n{"type":"worktree-state","sessionId":"sess-gone","worktreeSession":{"originalCwd":"%s","worktreePath":"%s/.claude/worktrees/removed","worktreeName":"removed","worktreeBranch":"removed","originalBranch":"main"}}\n' \
  "$mainreal" "$mainreal" "$mainreal" > "$attfeat/sess-gone.jsonl"
touch -t 202601040000 "$attfeat/sess-gone.jsonl"
out=$(cd "$main" && HOME="$atthome" SE_NO_PROMPT=1 "$se")
assert_contains "a session naming a removed worktree stays where it is stored" \
  "$out" "cd $featreal && claude --resume sess-gone"

rm -rf "$atthome"

# --- plan lookup: branch names contain characters the filename does not -----
# Claude Code's own worktrees produce branches like `worktree-fix+mobile`, but
# the plan file on disk has the `+` flattened. Looking only for the exact
# branch name misses a plan that is right there, and raises a false anomaly.
planhome=$(mktemp -d)
plusfeat2="$main/.claude/worktrees/feat+plus2"
git -C "$main" worktree add -q -b "feat+plus2" "$plusfeat2" main
mkdir -p "$plusfeat2/docs/plan"
printf '# plan\n\n## TODO\n- [x] 1. already done\n- [ ] 2. flattened plan step\n' \
  > "$plusfeat2/docs/plan/feat-plus2.md"

out=$(cd "$main" && HOME="$planhome" SE_NO_PROMPT=1 "$se")
assert_contains "plan found when the branch name flattens to the filename" \
  "$out" "flattened plan step"
assert_contains "its TODO progress is counted" "$out" "1/2"
assert_not_contains "no false missing-plan anomaly for a + branch" \
  "$out" "feat+plus2 — no plan file"

git -C "$main" worktree remove "$plusfeat2"
git -C "$main" branch -D "feat+plus2" >/dev/null 2>&1
rm -rf "$planhome"

# =================================================================== help ==
out=$(cd "$main" && "$se" help)
rc=$?
assert_exit "se help exits 0" 0 "$rc"
for sub in status env baseline teardown debt help; do
  assert_contains "se help mentions '$sub'" "$out" "$sub"
done
assert_contains "se help mentions SE_NO_PROMPT" "$out" "SE_NO_PROMPT"
assert_contains "se help mentions SE_COLOR" "$out" "SE_COLOR"

out=$(cd "$main" && "$se" bogus 2>&1)
rc=$?
assert_exit "se bogus exits 2" 2 "$rc"

# ================================================================= color ===
# $(...) capture never gives `se` a tty, so this is exactly the auto/off
# regression guard: no escape byte should ever leak into a piped/captured run.
esc=$(printf '\033')
colorhome=$(mktemp -d)

out_auto=$(cd "$main" && HOME="$colorhome" "$se")
assert_not_contains "default (auto, non-tty) output has no escape sequence" "$out_auto" "${esc}["

out_always=$(cd "$main" && HOME="$colorhome" SE_COLOR=always "$se")
assert_contains "SE_COLOR=always output has an escape sequence" "$out_always" "${esc}["

out_never=$(cd "$main" && HOME="$colorhome" SE_COLOR=never "$se")
assert_not_contains "SE_COLOR=never output has no escape sequence" "$out_never" "${esc}["

out_nocolor=$(cd "$main" && HOME="$colorhome" NO_COLOR=1 SE_COLOR=auto "$se")
assert_not_contains "NO_COLOR=1 SE_COLOR=auto output has no escape sequence" "$out_nocolor" "${esc}["

# Alignment regression: the colorized board, with escapes stripped, must be
# byte-identical to the plain one — this is the assertion that protects the
# table (printf pads by bytes; coloring before padding would corrupt it).
stripped_always=$(printf '%s\n' "$out_always" | sed "s/${esc}\[[0-9;]*m//g")
if [ "$out_auto" = "$stripped_always" ]; then
  ok "color does not change table alignment (stripped SE_COLOR=always == plain)"
else
  notok "color does not change table alignment (stripped SE_COLOR=always == plain)"
fi

rm -rf "$colorhome"

# =================================================================== env ===
out1=$(cd "$feat" && "$se" env)
rc1=$?
assert_exit "se env (first run) exits 0" 0 "$rc1"
assert_contains "se env copies .env (annotated object entry)" "$out1" "copy .env: done"
assert_true "se env leaves .env in the worktree" "$([ -f "$feat/.env" ] && echo 0 || echo 1)"
assert_contains "se env symlinks shared-dir (annotated object entry)" "$out1" "symlink shared-dir: done"
assert_true "se env leaves a real symlink for shared-dir" "$([ -L "$feat/shared-dir" ] && echo 0 || echo 1)"
assert_true "se env's postCreate hook creates pc-ran" "$([ -f "$feat/pc-ran" ] && echo 0 || echo 1)"

out2=$(cd "$feat" && "$se" env)
rc2=$?
assert_exit "se env (second run) exits 0" 0 "$rc2"
assert_contains "se env is idempotent (.env already present)" "$out2" "copy .env: already present"
assert_contains "se env is idempotent (shared-dir already present)" "$out2" "symlink shared-dir: already present"

# =============================================================== baseline ==
out=$(cd "$feat" && "$se" baseline)
rc=$?
assert_exit "se baseline exits 0" 0 "$rc"
pass_lines=$(printf '%s\n' "$out" | grep -cE '^PASS true ')
fail_lines=$(printf '%s\n' "$out" | grep -cE '^FAIL false ')
assert_true "se baseline prints one PASS line" "$([ "$pass_lines" -eq 1 ] && echo 0 || echo 1)"
assert_true "se baseline prints one FAIL line" "$([ "$fail_lines" -eq 1 ] && echo 0 || echo 1)"
assert_contains "se baseline prints why on a failing command" "$out" "always fails"
assert_true "se baseline writes scratchpad/baseline.md" "$([ -f "$feat/scratchpad/baseline.md" ] && echo 0 || echo 1)"

# =============================================================== teardown ==
# 1. unmerged — refuse. feat-x hasn't diverged from main with a real merge
#    yet, and the worktree is clean (the files env/baseline left behind are
#    all covered by .gitignore), so this exercises the merge gate.
out=$(cd "$main" && "$se" teardown feat-x 2>&1)
rc=$?
assert_exit "se teardown refuses while unmerged" 1 "$rc"
assert_contains "unmerged refusal names the reason" "$out" "not merged"
assert_true "worktree survives the unmerged refusal" "$([ -d "$feat" ] && echo 0 || echo 1)"

# 2. dirty — refuse, even though it would otherwise be mergeable.
echo junk > "$feat/junk.txt"
out=$(cd "$main" && "$se" teardown feat-x 2>&1)
rc=$?
assert_exit "se teardown refuses while dirty" 1 "$rc"
assert_contains "dirty refusal names the reason" "$out" "uncommitted changes"
rm -f "$feat/junk.txt"

# 3. merge it for real. Also drop rebuildable noise (node_modules) into the
#    worktree — excluded from the ignored-file gate, so it must not block
#    the successful teardown below.
printf 'change\n' >> "$feat/README.md"
git -C "$feat" add README.md
git -C "$feat" commit -q -m "feat: change"
git -C "$main" merge -q --no-ff -m "merge feat-x" feat-x >/dev/null

mkdir -p "$feat/node_modules/pkg"
echo "cache" > "$feat/node_modules/pkg/index.js"
# Per-checkout local state that main has too (a dev database). It is not
# unique, so the gate lets teardown proceed — but git cannot rmdir a
# non-empty directory, so leaving it here used to abort the removal after
# git had already unregistered the worktree.
mkdir -p "$feat/.data" "$main/.data"
echo "worktree db" > "$feat/.data/dev-shared.db"
echo "main db" > "$main/.data/dev-shared.db"
# Nested too: a monorepo's packages/*/node_modules is just as rebuildable,
# and must not read as a precious unique file.
mkdir -p "$feat/packages/app/node_modules/pkg"
echo "cache" > "$feat/packages/app/node_modules/pkg/index.js"

out=$(cd "$main" && "$se" teardown feat-x 2>&1)
rc=$?
assert_exit "se teardown succeeds once merged, clean, and free of unique ignored files" 0 "$rc"
assert_true "teardown removes the worktree directory" "$([ ! -d "$feat" ] && echo 0 || echo 1)"
assert_true "teardown deletes the branch" "$(git -C "$main" show-ref --verify -q refs/heads/feat-x && echo 1 || echo 0)"
assert_true "teardown's preDelete run entry executes (sentinel exists)" "$([ -f "$sentinel" ] && echo 0 || echo 1)"
assert_contains "teardown prints a manual-checks heading for check: entries" "$out" "manual checks (not run):"
assert_contains "teardown prints the check text verbatim" "$out" "touch $checkcanary"
assert_true "teardown never executes a check: entry" "$([ ! -e "$checkcanary" ] && echo 0 || echo 1)"
assert_contains "teardown says which local state it cleared" "$out" "clearing local state: .data"
assert_true "main's own local state is untouched" "$([ -f "$main/.data/dev-shared.db" ] && echo 0 || echo 1)"
assert_not_contains "teardown does not fail on a non-empty directory" "$out" "Directory not empty"

# ============================================== teardown: new hard gates ===
# feat-y: a config-declared `copy` file exists in the worktree and differs
# from main's copy — refuse, even though git itself sees the worktree as
# clean (the file is gitignored).
featY="$main/.claude/worktrees/feat-y"
git -C "$main" worktree add -q -b feat-y "$featY" main
cat > "$featY/docs/architecture/worktree.json" <<'EOF'
{"copy": [{"path": ".env", "required": true, "why": "local secret"}]}
EOF
git -C "$featY" add docs/architecture/worktree.json
git -C "$featY" commit -q -m "feat-y: config"
touch "$featY/feat-y-marker.txt"
git -C "$featY" add feat-y-marker.txt
git -C "$featY" commit -q -m "feat-y: marker"
git -C "$main" merge -q --no-ff -m "merge feat-y" feat-y >/dev/null

echo "DIFFERENT=1" > "$featY/.env"

out=$(cd "$main" && "$se" teardown feat-y 2>&1)
rc=$?
assert_exit "se teardown refuses when a config-declared copy file differs from main" 1 "$rc"
assert_contains "copy-gate refusal names .env" "$out" ".env"
assert_true "feat-y worktree survives the copy-gate refusal" "$([ -d "$featY" ] && echo 0 || echo 1)"

# feat-z: no copy config at all, but a unique gitignored file with no git
# history (a local db) exists only in the worktree — refuse.
featZ="$main/.claude/worktrees/feat-z"
git -C "$main" worktree add -q -b feat-z "$featZ" main
cat > "$featZ/docs/architecture/worktree.json" <<'EOF'
{"postCreate": [{"run": "true", "why": "no-op"}]}
EOF
git -C "$featZ" add docs/architecture/worktree.json
git -C "$featZ" commit -q -m "feat-z: config"
touch "$featZ/feat-z-marker.txt"
git -C "$featZ" add feat-z-marker.txt
git -C "$featZ" commit -q -m "feat-z: marker"
git -C "$main" merge -q --no-ff -m "merge feat-z" feat-z >/dev/null

mkdir -p "$featZ/.data"
echo "db-bytes" > "$featZ/.data/local.db"

out=$(cd "$main" && "$se" teardown feat-z 2>&1)
rc=$?
assert_exit "se teardown refuses when a unique ignored file exists only in the worktree" 1 "$rc"
assert_contains "ignored-file refusal names .data/local.db" "$out" ".data/local.db"
assert_true "feat-z worktree survives the ignored-file refusal" "$([ -d "$featZ" ] && echo 0 || echo 1)"

# ============================================================ schema: env ==
# required:true copy missing from main -> se env fails loudly.
reqrepo="$tmpdir/reqrepo"
mkdir -p "$reqrepo/docs/architecture"
git -C "$reqrepo" init -q -b main
cat > "$reqrepo/docs/architecture/worktree.json" <<'EOF'
{"copy": [{"path": ".missing-secret", "required": true, "why": "must exist"}]}
EOF

out=$(cd "$reqrepo" && "$se" env 2>&1)
rc=$?
assert_exit "se env fails when a required copy entry is missing from main" 1 "$rc"
assert_contains "required-missing message names the file" "$out" ".missing-secret"

# bare-string shorthand still works. Uses a real worktree (not the main
# checkout itself) so "copy" has an actual main -> worktree direction to
# prove: pre-creating .env in the same dir would trivially read "already
# present" and prove nothing.
barerepo="$tmpdir/barerepo"
mkdir -p "$barerepo/docs/architecture"
git -C "$barerepo" init -q -b main
git -C "$barerepo" config user.email test@example.com
git -C "$barerepo" config user.name Test
printf '.env\n' > "$barerepo/.gitignore"
cat > "$barerepo/docs/architecture/worktree.json" <<'EOF'
{"copy": [".env"], "postCreate": ["touch bare-pc-ran"], "baseline": ["true"]}
EOF
git -C "$barerepo" add -A
git -C "$barerepo" commit -q -m init
echo "SECRET=1" > "$barerepo/.env"

bareWt="$barerepo/wt"
git -C "$barerepo" worktree add -q -b bare-wt "$bareWt" main

out=$(cd "$bareWt" && "$se" env)
rc=$?
assert_exit "se env (bare-string shorthand) exits 0" 0 "$rc"
assert_contains "bare-string copy shorthand works" "$out" "copy .env: done"
assert_true "bare-string postCreate shorthand runs" "$([ -f "$bareWt/bare-pc-ran" ] && echo 0 || echo 1)"

out=$(cd "$bareWt" && "$se" baseline)
rc=$?
assert_exit "se baseline (bare-string shorthand) exits 0" 0 "$rc"
assert_contains "bare-string baseline shorthand runs" "$out" "PASS true "

# old nested layout -> se env exits 1 with a migration message.
oldrepo="$tmpdir/oldrepo"
mkdir -p "$oldrepo/docs/architecture"
git -C "$oldrepo" init -q -b main
cat > "$oldrepo/docs/architecture/worktree.json" <<'EOF'
{"sync": {"copyFiles": [".env"]}, "hooks": {"postCreate": ["npm ci"]}, "baseline": {"commands": ["npm test"]}}
EOF

out=$(cd "$oldrepo" && "$se" env 2>&1)
rc=$?
assert_exit "se env exits 1 on the old nested layout" 1 "$rc"
assert_contains "old-layout message names the migration" "$out" "old nested layout"

# garbage/unrecognized keys -> se env exits 1 with the generic message.
garbagerepo="$tmpdir/garbagerepo"
mkdir -p "$garbagerepo/docs/architecture"
git -C "$garbagerepo" init -q -b main
cat > "$garbagerepo/docs/architecture/worktree.json" <<'EOF'
{"foo": "bar", "setupSteps": ["do a thing"]}
EOF

out=$(cd "$garbagerepo" && "$se" env 2>&1)
rc=$?
assert_exit "se env exits 1 on unrecognized-keys config" 1 "$rc"
assert_contains "unrecognized-keys message lists a canonical key" "$out" "copy"

# ===================================================================== debt =
debtrepo="$tmpdir/debtrepo"
mkdir -p "$debtrepo/src"
git -C "$debtrepo" init -q -b main
printf '# se-debt: temp shortcut, revisit at 10k rps\n' > "$debtrepo/src/a.py"
printf '// se-debt: no trigger\n' > "$debtrepo/src/b.js"
printf 'This project tracks se-debt: markers for shortcuts.\n' > "$debtrepo/NOTES.md"

out=$(cd "$debtrepo" && "$se" debt)
rc=$?
assert_exit "se debt exits 0 (markers present)" 0 "$rc"
rows=$(printf '%s\n' "$out" | grep -cE '^src/[ab]\.(py|js):1  se-debt:')
assert_true "se debt reports exactly 2 rows" "$([ "$rows" -eq 2 ] && echo 0 || echo 1)"
notrigger=$(printf '%s\n' "$out" | grep -c '\[no-trigger\]')
assert_true "se debt flags exactly 1 marker as [no-trigger]" "$([ "$notrigger" -eq 1 ] && echo 0 || echo 1)"
assert_contains "se debt's [no-trigger] tag is on b.js" "$out" "src/b.js:1  se-debt: no trigger [no-trigger]"
assert_contains "se debt prints a correct summary" "$out" "2 markers, 1 without trigger."

cleanrepo="$tmpdir/cleanrepo"
mkdir -p "$cleanrepo"
git -C "$cleanrepo" init -q -b main
out=$(cd "$cleanrepo" && "$se" debt)
rc=$?
assert_exit "se debt exits 0 (clean repo)" 0 "$rc"
assert_contains "se debt reports a clean ledger" "$out" "No se-debt markers. Clean ledger."

# ============================================================ resume picker =
# `se status`'s resume menu prompts interactively only when stdin+stdout are
# both a real terminal. Drive it through a pty (macOS `script`) so the tty
# checks pass, with a fake `claude` on PATH so nothing real ever launches.
pickrepo="$tmpdir/pickrepo"
mkdir -p "$pickrepo"
git -C "$pickrepo" init -q -b main
git -C "$pickrepo" config user.email test@example.com
git -C "$pickrepo" config user.name Test
printf '# fixture\n' > "$pickrepo/README.md"
git -C "$pickrepo" add -A
git -C "$pickrepo" commit -q -m init
pickrepo_real=$(cd "$pickrepo" && pwd -P)

# A saved session for the (only) worktree, so its resume row is "join ->
# --continue" rather than "fresh, no saved session".
pickhome=$(mktemp -d)
pick_enc=$(printf '%s' "$pickrepo_real" | tr '/.' '--')
mkdir -p "$pickhome/.claude/projects/$pick_enc"
printf '{"aiTitle":"pick test session"}\n' > "$pickhome/.claude/projects/$pick_enc/sess1.jsonl"

fakebin="$tmpdir/fakebin"
mkdir -p "$fakebin"
fakelog="$tmpdir/fake-claude.log"
cat > "$fakebin/claude" <<CLAUDEEOF
#!/bin/sh
{
  echo "cwd:\$(pwd -P)"
  echo "args:\$*"
} >> "$fakelog"
CLAUDEEOF
chmod +x "$fakebin/claude"

pick_rcfile="$tmpdir/pick-rc"
run_picker() { # $1 = stdin to feed the pty
  # The trailing sleep keeps the write end of the pipe open a moment after
  # the input is written: `script` tears the pty down as soon as its own
  # stdin hits EOF, which otherwise races the child's `read` and can kill it
  # before the input is ever consumed.
  # SE_COLOR=never: this test drives the interactive picker over a real pty
  # (so [ -t 1 ] is true and auto-color would kick in) but only cares about
  # the plain text — color itself is covered separately below.
  { printf '%s' "$1"; sleep 0.5; } | script -q /dev/null sh -c "cd '$pickrepo' || exit 1; PATH='$fakebin:'\"\$PATH\" HOME='$pickhome' SE_COLOR=never '$se'; echo \$? > '$pick_rcfile'" 2>&1
}

# A real resume_launch call always logs args exactly "" (bare `claude`) or
# "--resume <id>" — distinct from the harmless `claude agents --json` probe
# cmd_status's live overlay also makes through the same fake claude on PATH.
launched() { grep -qE '^args:(--resume [^ ]+)?$' "$fakelog"; }

have_pty=0
if command -v script >/dev/null 2>&1; then
  ptytest=$(script -q /dev/null sh -c '[ -t 0 ] && [ -t 1 ] && echo PTY_OK' 2>/dev/null)
  case "$ptytest" in *PTY_OK*) have_pty=1 ;; esac
fi

if [ "$have_pty" -eq 1 ]; then
  : > "$fakelog"
  out=$(run_picker $'q\n')
  rc=$(cat "$pick_rcfile" 2>/dev/null)
  assert_exit "resume picker: q exits 0" 0 "$rc"
  assert_true "resume picker: q launches nothing" "$(launched && echo 1 || echo 0)"

  # Interactive rows sit under a heading naming the branch; the runnable
  # `cd ... && claude` form is for the non-interactive output, where a bare
  # name would be useless.
  assert_contains "picker groups rows under the branch" "$out" "  main"
  assert_contains "picker rows are indented under their group" "$out" "    1 "
  assert_contains "picker menu names the session" "$out" "pick test session"
  assert_not_contains "picker menu drops the full cd command" "$out" "&& claude"

  : > "$fakelog"
  out=$(run_picker $'zzz\nq\n')
  rc=$(cat "$pick_rcfile" 2>/dev/null)
  assert_exit "resume picker: invalid choice then q exits 0" 0 "$rc"
  assert_contains "resume picker: invalid choice re-prompts" "$out" "not a valid choice"
  assert_true "resume picker: invalid choice then q launches nothing" "$(launched && echo 1 || echo 0)"

  : > "$fakelog"
  run_picker $'1\n' >/dev/null
  log=$(cat "$fakelog" 2>/dev/null)
  assert_contains "resume picker: choosing 1 resumes that session by id" "$log" "args:--resume sess1"
  assert_contains "resume picker: choosing 1 launches in the right directory" "$log" "cwd:$pickrepo_real"

  : > "$fakelog"
  run_picker $'n1\n' >/dev/null
  log=$(cat "$fakelog" 2>/dev/null)
  assert_true "resume picker: n1 invokes claude" "$(launched && echo 0 || echo 1)"
  assert_not_contains "resume picker: n1 starts fresh rather than resuming" "$log" "args:--resume"
  assert_contains "resume picker: n1 launches in the right directory" "$log" "cwd:$pickrepo_real"
else
  printf 'SKIP - resume picker: q exits 0 and launches nothing (no pty available)\n'
  printf 'SKIP - resume picker: invalid choice re-prompts (no pty available)\n'
  printf 'SKIP - resume picker: choosing 1 resumes that session by id in the right directory (no pty available)\n'
  printf 'SKIP - resume picker: n1 starts fresh in the right directory (no pty available)\n'
fi
rm -rf "$pickhome"

printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
