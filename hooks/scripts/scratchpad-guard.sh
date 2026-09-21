#!/usr/bin/env bash
# PreToolUse guard for Write, Edit and Bash.
# The harness hands every session a per-session temp scratchpad
# (/tmp/claude-<uid>/<project>/<session>/scratchpad) and tells agents to use
# it. This plugin's projects carry their own gitignored scratchpad/ instead:
# it survives the session, sits next to the work, and is what `se env`
# creates. Anything aimed at the harness scratchpad is refused and redirected
# there. Exit 2 blocks the tool call; stderr is fed back to Claude.
#
# Allowed on purpose: reads (Read is not matched), tool calls whose cwd is
# not inside a git repo (there is no project scratchpad to point at), and
# every other harness path (task transcripts, uploads) - only the scratchpad
# directory itself is redirected.

set -u

input=$(cat)

# Two fields, one python invocation; python3 rather than jq, as git-guard.sh.
fields=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    ti = d.get("tool_input") or {}
    target = ti.get("file_path") or ti.get("command") or ""
    print(d.get("tool_name", ""))
    print(d.get("cwd", ""))
    print(target.replace("\n", " "))
except Exception:
    pass
' 2>/dev/null)

tool=$(printf '%s\n' "$fields" | sed -n 1p)
cwd=$(printf '%s\n' "$fields" | sed -n 2p)
target=$(printf '%s\n' "$fields" | sed -n 3p)

# Only tools that write. The matcher already narrows this, but the script
# defends itself so a wider matcher can never turn it into a read blocker.
case "$tool" in
  Write|Edit|MultiEdit|Bash) ;;
  *) exit 0 ;;
esac

[ -n "$target" ] || exit 0

# The harness scratchpad, in either of its spellings on macOS (/private/tmp
# and /tmp) and on Linux (/tmp). Three fixed segments after claude-<uid>:
# encoded project dir, session id, then the literal "scratchpad", ended by
# a slash, any non-path character (space, quote, ; & |), or end of string.
seg='[A-Za-z0-9._-]+'
pattern="(/private)?/tmp/claude-$seg/$seg/$seg/scratchpad([^A-Za-z0-9._-]|$)"
[[ "$target" =~ $pattern ]] || exit 0

root=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Redirecting to a directory that does not exist would just move the
# failure, so build the sandbox here: create it, and ignore it locally
# through info/exclude when nothing ignores it yet (no commit needed; `se
# env` and `/se:setup` do the same). --git-path resolves the shared
# info/exclude correctly from inside a linked worktree.
if [ -d "$root/scratchpad" ]; then
  state="already there"
else
  mkdir -p "$root/scratchpad" 2>/dev/null && state="created it" || state="could not create it"
fi
if ! git -C "$root" check-ignore -q scratchpad 2>/dev/null; then
  exclude=$(git -C "$root" rev-parse --git-path info/exclude 2>/dev/null)
  case "$exclude" in
    /*) : ;;
    ?*) exclude="$root/$exclude" ;;
  esac
  if [ -n "$exclude" ]; then
    { mkdir -p "$(dirname "$exclude")" && printf 'scratchpad/\n' >> "$exclude"; } 2>/dev/null
  fi
fi

printf '%s\n' "Blocked: the harness temp scratchpad is not this project's sandbox. Use $root/scratchpad/ instead ($state; gitignored, survives the session)." >&2
exit 2
