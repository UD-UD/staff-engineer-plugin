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
rm -rf "$emptyhome"

# =================================================================== help ==
out=$(cd "$main" && "$se" help)
rc=$?
assert_exit "se help exits 0" 0 "$rc"
for sub in status env baseline teardown debt help; do
  assert_contains "se help mentions '$sub'" "$out" "$sub"
done

out=$(cd "$main" && "$se" bogus 2>&1)
rc=$?
assert_exit "se bogus exits 2" 2 "$rc"

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

printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
