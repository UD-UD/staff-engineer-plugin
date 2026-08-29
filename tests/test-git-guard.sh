#!/bin/bash
# Exercises hooks/scripts/git-guard.sh: feed it the same JSON shape Claude
# Code's PreToolUse hook sends on stdin, assert the exit code. 2 = blocked,
# 0 = allowed. Never modifies git-guard.sh; only ever pipes into it.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
guard="$root/hooks/scripts/git-guard.sh"

pass=0
fail=0

ok() { pass=$((pass + 1)); printf 'ok - %s\n' "$1"; }
notok() { fail=$((fail + 1)); printf 'not ok - %s\n' "$1"; }

assert_exit() { # desc expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else notok "$1 (expected exit $2, got $3)"; fi
}

# Runs git-guard.sh with {"tool_input":{"command":cmd}[,"cwd":cwd]} on
# stdin; prints the exit code (json-encoded via python3 so quotes/newlines
# in the command never break the payload).
guard_rc() { # cmd [cwd]
  python3 - "$1" "${2:-}" <<'PY' | /bin/bash "$guard" >/dev/null 2>/dev/null
import json, sys
cmd, cwd = sys.argv[1], sys.argv[2]
d = {"tool_input": {"command": cmd}}
if cwd:
    d["cwd"] = cwd
print(json.dumps(d))
PY
  echo $?
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# cwd-dependent fixtures: one repo on main, one on a feature branch. No
# commits needed — `git branch --show-current` works right after init.
mainrepo="$tmpdir/mainrepo"
mkdir -p "$mainrepo"
git -C "$mainrepo" init -q -b main

featrepo="$tmpdir/featrepo"
mkdir -p "$featrepo"
git -C "$featrepo" init -q -b feature/x

# --- Rule 1: no bypassing commit hooks --------------------------------------
rc=$(guard_rc 'git commit --no-verify -m "fix"')
assert_exit "git commit --no-verify blocked" 2 "$rc"

# --- Rule 2: no agent authorship in commits ---------------------------------
rc=$(guard_rc 'git commit -m "fix: bug. Co-Authored-By: Claude <noreply@anthropic.com>"')
assert_exit "commit with Co-Authored-By: Claude blocked" 2 "$rc"

rc=$(guard_rc 'git commit -m "fix: bug. Claude-Session: https://claude.ai/code/session_x"')
assert_exit "commit with Claude-Session: blocked" 2 "$rc"

rc=$(guard_rc 'git commit -m "fix: bug. Co-Authored-By: Jane <jane@x.dev>"' "$featrepo")
assert_exit "commit with human co-author trailer allowed" 0 "$rc"

# --- Rule 2b: no agent authorship in PRs ------------------------------------
rc=$(guard_rc 'gh pr create --title "feat: x" --body "Nice feature. Generated with Claude Code"')
assert_exit "gh pr create with Generated with Claude Code blocked" 2 "$rc"

rc=$(guard_rc 'gh pr edit 5 --body "See session https://claude.ai/code/session_xyz"')
assert_exit "gh pr edit with claude.ai/code link blocked" 2 "$rc"

# --- Rule 3: no plain force-push --------------------------------------------
rc=$(guard_rc 'git push --force origin feature/x')
assert_exit "git push --force blocked" 2 "$rc"

rc=$(guard_rc 'git push --force-with-lease origin feature/x')
assert_exit "git push --force-with-lease allowed" 0 "$rc"

# --- Rule 4: main is untouched -----------------------------------------------
rc=$(guard_rc 'git commit -m "fix"' "$featrepo")
assert_exit "plain commit on feature branch allowed" 0 "$rc"

rc=$(guard_rc 'git commit -m "fix"' "$mainrepo")
assert_exit "plain commit on main branch blocked" 2 "$rc"

# --- Rule 5: no forced worktree removal -------------------------------------
rc=$(guard_rc 'git worktree remove --force x')
assert_exit "git worktree remove --force blocked" 2 "$rc"

# --- Sanity: an unrelated command is never touched --------------------------
rc=$(guard_rc 'git status' "$featrepo")
assert_exit "plain git status allowed" 0 "$rc"

printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
