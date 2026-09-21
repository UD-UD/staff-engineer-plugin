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

# --- Rule 6: no debug tags in the working tree ------------------------------
# Tag built via printf so this file never contains the literal debug-tag
# spelling (guarded by the self-check assertion further down).
debugrepo="$tmpdir/debugrepo"
mkdir -p "$debugrepo"
git -C "$debugrepo" init -q -b feature/debug
tag=$(printf '[DEBUG-%s]' a4f2)

printf 'before\n%s\nafter\n' "$tag" > "$debugrepo/tracked.txt"
git -C "$debugrepo" add tracked.txt

rc=$(guard_rc 'git commit -m x' "$debugrepo")
assert_exit "commit blocked: debug tag in tracked file" 2 "$rc"

printf 'before\nafter\n' > "$debugrepo/tracked.txt"
git -C "$debugrepo" add tracked.txt
printf '%s\n' "$tag" > "$debugrepo/untracked.txt"

rc=$(guard_rc 'git commit -m x' "$debugrepo")
assert_exit "commit blocked: debug tag in untracked file (proves --untracked)" 2 "$rc"

rm -f "$debugrepo/untracked.txt"

rc=$(guard_rc 'git commit -m x' "$debugrepo")
assert_exit "commit allowed: debug tag removed" 0 "$rc"

printf '[DEBUG-xxxx]\n' > "$debugrepo/docs.txt"

rc=$(guard_rc 'git commit -m x' "$debugrepo")
assert_exit "commit allowed: docs-safe [DEBUG-xxxx] spelling does not match" 0 "$rc"

# Hex is hex in either case: a tag typed with capitals is the same tag.
uptag=$(printf '[DEBUG-%s]' A4F2)
printf '%s\n' "$uptag" > "$debugrepo/upper.txt"

rc=$(guard_rc 'git commit -m x' "$debugrepo")
assert_exit "commit blocked: uppercase-hex debug tag" 2 "$rc"

rm -f "$debugrepo/upper.txt"

# A commit stages the whole index no matter which directory it is typed in,
# so the scan has to cover the whole repo, not the hook's cwd subtree.
mkdir -p "$debugrepo/sub"
printf '%s\n' "$tag" > "$debugrepo/root-tag.txt"

rc=$(guard_rc 'git commit -m x' "$debugrepo/sub")
assert_exit "commit blocked: tag at repo root, commit run from a subdirectory" 2 "$rc"

rm -f "$debugrepo/root-tag.txt"

rc=$(guard_rc 'git commit -m x' "$debugrepo/sub")
assert_exit "commit allowed from a subdirectory once the tag is gone" 0 "$rc"

self_hits=$(git -C "$root" grep -lE --untracked -e '\[DEBUG-[0-9a-fA-F]{4}\]' -- :/ 2>/dev/null)
if [ -z "$self_hits" ]; then
  ok "plugin repo has no literal debug-tag hits on itself"
else
  notok "plugin repo has no literal debug-tag hits on itself (found: $self_hits)"
fi

printf '%s\n' "$tag" > "$debugrepo/untracked.txt"
rc=$(guard_rc 'git status' "$debugrepo")
assert_exit "plain git status allowed in tagged repo" 0 "$rc"

# --- Sanity: an unrelated command is never touched --------------------------
rc=$(guard_rc 'git status' "$featrepo")
assert_exit "plain git status allowed" 0 "$rc"

printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
