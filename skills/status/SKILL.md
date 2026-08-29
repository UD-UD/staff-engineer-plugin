---
name: status
description: Use when picking work back up after a break, reboot, or context switch - "where was I", "what's in flight", "resume work", "which worktrees" - or to see every worktree and how to resume each Claude Code session. Runs the plugin's deterministic `se` command and helps act on what it reports.
---

# Status Board (thin wrapper)

The board is deterministic — never re-derive by hand what the script prints.

1. Run `se` (on PATH when the plugin is installed; fallback:
   `"${CLAUDE_PLUGIN_ROOT}/bin/se"`). Show its output to the user verbatim.
2. Everything it prints comes from durable on-disk state (git, `docs/plan/`
   TODO checklists, session transcripts under `~/.claude/projects/`), so it
   is correct even right after a reboot. The `● running` markers are a live
   overlay only.
3. Your job is what the script can't do — act on its anomaly lines when the
   user wants:
   - merged-but-not-torn-down → safe teardown (worktree skill, step 5).
   - no plan file → offer `/se:plan`.
   - stale worktrees → ask if abandoned; never tear down on your own.
   - a dirty worktree with no saved session → its sessions may live under a
     different encoded dir (path was moved/renamed, or sessions were started
     in a subdirectory). Ground truth: the `"cwd"` field inside jsonls under
     `~/.claude/projects/*/`, or `~/.claude/history.jsonl` which maps every
     prompt to {project, sessionId}.
4. To resume a session other than the most recent one in a worktree:
   `cd <worktree> && claude --resume` opens that directory's session picker
   (`--fork-session` revisits one without advancing it).
