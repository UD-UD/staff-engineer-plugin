#!/usr/bin/env bash
# PreToolUse guard for Bash tool calls.
# Blocks git invocations that bypass the safety checks this plugin exists to
# enforce. Exit 2 blocks the tool call; the stderr message is fed back to
# Claude so it can correct course instead of retrying blindly.

set -u

input=$(cat)

# Hook input is JSON on stdin; the command lives at .tool_input.command.
# python3 ships with macOS/Linux dev setups; jq often does not.
cmd=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    pass
' 2>/dev/null)

[ -z "$cmd" ] && exit 0

cwd=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("cwd", ""))
except Exception:
    pass
' 2>/dev/null)

lc_cmd=$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')

block() {
  printf '%s\n' "$1" >&2
  exit 2
}

# --- Rule 1: no bypassing commit hooks -------------------------------------
# Catches --no-verify and the -n shorthand on git commit.
if [[ "$cmd" =~ git[[:space:]]+commit ]]; then
  if [[ "$cmd" =~ --no-verify ]] || [[ "$cmd" =~ [[:space:]]-n([[:space:]]|$) ]]; then
    block "Blocked: 'git commit --no-verify' bypasses commit hooks. Fix whatever the hook is failing on instead of skipping it."
  fi
fi

# --- Rule 2: no agent authorship in commits --------------------------------
# Git history is human-owned. Catches the AI attribution trailers/footers
# that agent tooling appends to commit messages by default. Case-insensitive
# via the lowercased command; human co-author trailers are unaffected.
if [[ "$lc_cmd" =~ git[[:space:]]+commit ]]; then
  if [[ "$lc_cmd" == *"co-authored-by: claude"* ]] || \
     [[ "$lc_cmd" == *"noreply@anthropic.com"* ]] || \
     [[ "$lc_cmd" == *"claude-session:"* ]] || \
     [[ "$lc_cmd" == *"generated with"*"claude"* ]]; then
    block "Blocked: no agent authorship in commits. Rewrite the commit message without Co-Authored-By: Claude, Claude-Session, or 'Generated with Claude Code' attribution — the user authors their own history."
  fi
fi

# --- Rule 2b: no agent authorship in PRs -----------------------------------
# Same rule as commits, applied to PR titles/bodies written via the gh CLI.
if [[ "$lc_cmd" =~ gh[[:space:]]+pr[[:space:]]+(create|edit) ]]; then
  if [[ "$lc_cmd" == *"generated with"*"claude"* ]] || \
     [[ "$lc_cmd" == *"claude.ai/code"* ]] || \
     [[ "$lc_cmd" == *"co-authored-by: claude"* ]] || \
     [[ "$lc_cmd" == *"noreply@anthropic.com"* ]]; then
    block "Blocked: no agent authorship in PRs. Remove 'Generated with Claude Code' footers, claude.ai session links, and any AI attribution from the PR title/body — the user authors their own history."
  fi
fi

# --- Rule 3: no plain force-push -------------------------------------------
# --force-with-lease is the acceptable form; bare --force / -f is not.
if [[ "$cmd" =~ git[[:space:]]+push ]] && [[ ! "$cmd" =~ --force-with-lease ]]; then
  if [[ "$cmd" =~ --force([[:space:]]|$) ]] || [[ "$cmd" =~ [[:space:]]-f([[:space:]]|$) ]]; then
    block "Blocked: plain force-push can destroy remote history. Use 'git push --force-with-lease' if a rewrite is truly needed, and never against a shared branch."
  fi
  if [[ "$cmd" =~ --no-verify ]]; then
    block "Blocked: 'git push --no-verify' bypasses pre-push hooks. Fix the underlying failure instead."
  fi
fi

# --- Rule 4: main is untouched ---------------------------------------------
# Features live in worktrees; direct commits on main/master are blocked.
# Escape hatch (explicit user approval only): prefix the command with
# STAFF_ENGINEER_ALLOW_MAIN=1 so the override stays visible in the transcript.
if [[ "$lc_cmd" =~ git[[:space:]]+commit ]] && [[ "$lc_cmd" != *staff_engineer_allow_main=1* ]]; then
  branch=$(git -C "${cwd:-.}" branch --show-current 2>/dev/null)
  case "$branch" in
    main|master)
      block "Blocked: direct commits to '$branch' are not allowed — features start in a worktree (see /se:worktree). If the user explicitly approved committing to $branch, prefix the command with STAFF_ENGINEER_ALLOW_MAIN=1."
      ;;
  esac
fi

# --- Rule 5: no forced worktree removal ------------------------------------
# 'git worktree remove --force' discards a dirty worktree's uncommitted
# changes unrecoverably. If plain remove refuses, that's a signal, not an
# obstacle.
if [[ "$lc_cmd" =~ git[[:space:]]+worktree[[:space:]]+remove ]]; then
  if [[ "$lc_cmd" =~ --force([[:space:]]|$) ]] || [[ "$lc_cmd" =~ [[:space:]]-f([[:space:]]|$) ]]; then
    block "Blocked: 'git worktree remove --force' discards uncommitted work unrecoverably. Check 'git status' in the worktree, save what matters, then remove without --force."
  fi
fi

exit 0
