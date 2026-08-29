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
} > "$main/.gitignore"

sentinel="$tmpdir/predelete-sentinel"
mkdir -p "$main/docs/architecture"
cat > "$main/docs/architecture/worktree.json" <<EOF
{
  "sync": {"copyFiles": [".env"]},
  "hooks": {
    "postCreate": ["touch pc-ran"],
    "preDelete": ["touch $sentinel"]
  },
  "baseline": {"commands": ["true", "false"]}
}
EOF

git -C "$main" add -A
git -C "$main" commit -q -m init

# .env lives only in main (untracked, gitignored) — sync.copyFiles source.
echo "SECRET=1" > "$main/.env"

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
assert_contains "se env copies .env" "$out1" "copy .env: done"
assert_true "se env leaves .env in the worktree" "$([ -f "$feat/.env" ] && echo 0 || echo 1)"
assert_true "se env's postCreate hook creates pc-ran" "$([ -f "$feat/pc-ran" ] && echo 0 || echo 1)"

out2=$(cd "$feat" && "$se" env)
rc2=$?
assert_exit "se env (second run) exits 0" 0 "$rc2"
assert_contains "se env is idempotent (.env already present)" "$out2" "copy .env: already present"

# =============================================================== baseline ==
out=$(cd "$feat" && "$se" baseline)
rc=$?
assert_exit "se baseline exits 0" 0 "$rc"
pass_lines=$(printf '%s\n' "$out" | grep -cE '^PASS true ')
fail_lines=$(printf '%s\n' "$out" | grep -cE '^FAIL false ')
assert_true "se baseline prints one PASS line" "$([ "$pass_lines" -eq 1 ] && echo 0 || echo 1)"
assert_true "se baseline prints one FAIL line" "$([ "$fail_lines" -eq 1 ] && echo 0 || echo 1)"
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

# 3. merge it for real, then teardown should succeed.
printf 'change\n' >> "$feat/README.md"
git -C "$feat" add README.md
git -C "$feat" commit -q -m "feat: change"
git -C "$main" merge -q --no-ff -m "merge feat-x" feat-x >/dev/null

out=$(cd "$main" && "$se" teardown feat-x 2>&1)
rc=$?
assert_exit "se teardown succeeds once merged and clean" 0 "$rc"
assert_true "teardown removes the worktree directory" "$([ ! -d "$feat" ] && echo 0 || echo 1)"
assert_true "teardown deletes the branch" "$(git -C "$main" show-ref --verify -q refs/heads/feat-x && echo 1 || echo 0)"
assert_true "teardown's preDelete sentinel exists" "$([ -f "$sentinel" ] && echo 0 || echo 1)"

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
