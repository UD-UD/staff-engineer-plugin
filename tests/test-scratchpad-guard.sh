#!/bin/bash
# Exercises hooks/scripts/scratchpad-guard.sh: feed it the JSON shape Claude
# Code's PreToolUse hook sends for Write, Edit and Bash, assert the exit
# code. 2 = blocked, 0 = allowed. Never modifies the guard; only pipes into it.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
guard="$root/hooks/scripts/scratchpad-guard.sh"

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

# Runs the guard with {"tool_name":..,"tool_input":{...},"cwd":..} on stdin;
# prints the exit code. field is file_path (Write/Edit) or command (Bash).
guard_rc() { # tool field value cwd
  python3 - "$1" "$2" "$3" "$4" <<'PY' | /bin/bash "$guard" >/dev/null 2>/dev/null
import json, sys
tool, field, value, cwd = sys.argv[1:5]
print(json.dumps({"tool_name": tool, "tool_input": {field: value}, "cwd": cwd}))
PY
  echo $?
}

guard_err() { # tool field value cwd -> stderr text
  python3 - "$1" "$2" "$3" "$4" <<'PY' | /bin/bash "$guard" 2>&1 >/dev/null
import json, sys
tool, field, value, cwd = sys.argv[1:5]
print(json.dumps({"tool_name": tool, "tool_input": {field: value}, "cwd": cwd}))
PY
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/repo"
mkdir -p "$repo"
git -C "$repo" init -q -b main

plain="$tmpdir/plain"
mkdir -p "$plain"

# The shape Claude Code uses for its per-session temp scratchpad.
harness="/private/tmp/claude-504/-Users-dev-workshop-app/aa91046a-c37b-418b-b543-1a199b662f12/scratchpad"
harness_short="/tmp/claude-1000/-home-dev-app/0f2bdbd0-1234-5678-9abc-def012345678/scratchpad"

# --- blocked: writes into the harness scratchpad ---------------------------
rc=$(guard_rc Write file_path "$harness/notes.md" "$repo")
assert_exit "Write into harness scratchpad blocked" 2 "$rc"

rc=$(guard_rc Edit file_path "$harness/sub/dir/notes.md" "$repo")
assert_exit "Edit under harness scratchpad blocked" 2 "$rc"

rc=$(guard_rc Write file_path "$harness_short/x.txt" "$repo")
assert_exit "Write into /tmp-form harness scratchpad blocked" 2 "$rc"

rc=$(guard_rc Bash command "mkdir -p $harness/fixture && cp a.txt $harness/fixture/" "$repo")
assert_exit "Bash command naming the harness scratchpad blocked" 2 "$rc"

rc=$(guard_rc Bash command "scratch=$harness; mkdir -p \"\$scratch/x\"" "$repo")
assert_exit "Bash assigning the harness scratchpad to a variable blocked" 2 "$rc"

err=$(guard_err Write file_path "$harness/notes.md" "$repo")
assert_contains "block message names the project scratchpad" "$err" "$repo/scratchpad"

# --- a block builds the project scratchpad if it is missing -----------------
[ -d "$repo/scratchpad" ] && ok "project scratchpad created on first block" \
  || notok "project scratchpad created on first block"
git -C "$repo" check-ignore -q scratchpad && ok "created scratchpad is gitignored" \
  || notok "created scratchpad is gitignored"
# $err above was captured after an earlier block had already built it.
assert_contains "a later block says the scratchpad already exists" "$err" "already there"

# A repo that ignores scratchpad/ through .gitignore gets no exclude entry;
# its first block is the one that creates the directory.
repo2="$tmpdir/repo2"
mkdir -p "$repo2"
git -C "$repo2" init -q -b main
printf 'scratchpad/\n' > "$repo2/.gitignore"
err=$(guard_err Write file_path "$harness/notes.md" "$repo2")
assert_contains "first block says the scratchpad was created" "$err" "created it"
rc=$(guard_rc Write file_path "$harness/notes.md" "$repo2")
assert_exit "block in a repo whose .gitignore already covers scratchpad" 2 "$rc"
[ -d "$repo2/scratchpad" ] && ok "scratchpad created in repo2" || notok "scratchpad created in repo2"
excl=$(git -C "$repo2" rev-parse --git-path info/exclude)
if [ -f "$excl" ] && grep -q '^scratchpad/$' "$excl"; then
  notok "no exclude entry added when .gitignore already covers it"
else
  ok "no exclude entry added when .gitignore already covers it"
fi

# --- allowed: the project's own scratchpad and everything else --------------
rc=$(guard_rc Write file_path "$repo/scratchpad/notes.md" "$repo")
assert_exit "Write into project scratchpad allowed" 0 "$rc"

rc=$(guard_rc Edit file_path "$repo/src/main.py" "$repo")
assert_exit "Edit of a source file allowed" 0 "$rc"

rc=$(guard_rc Bash command "ls $repo/scratchpad" "$repo")
assert_exit "Bash on the project scratchpad allowed" 0 "$rc"

rc=$(guard_rc Bash command "cat /private/tmp/claude-504/-Users-dev-app/aa91046a-c37b-418b-b543-1a199b662f12/tasks/x.output" "$repo")
assert_exit "Bash reading a non-scratchpad harness file allowed" 0 "$rc"

rc=$(guard_rc Bash command "git status" "$repo")
assert_exit "unrelated Bash allowed" 0 "$rc"

# --- allowed: no project to redirect to -------------------------------------
rc=$(guard_rc Write file_path "$harness/notes.md" "$plain")
assert_exit "harness scratchpad allowed when cwd is not a git repo" 0 "$rc"

# --- robustness -------------------------------------------------------------
rc=$(printf 'not json' | /bin/bash "$guard" >/dev/null 2>&1; echo $?)
assert_exit "malformed input never blocks" 0 "$rc"

rc=$(printf '{"tool_name":"Read","tool_input":{"file_path":"%s/x"},"cwd":"%s"}' "$harness" "$repo" | /bin/bash "$guard" >/dev/null 2>&1; echo $?)
assert_exit "Read from the harness scratchpad allowed" 0 "$rc"

printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
