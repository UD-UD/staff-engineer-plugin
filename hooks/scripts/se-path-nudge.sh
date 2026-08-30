#!/usr/bin/env bash
# SessionStart hook: one-time nudge to link the `se` terminal command onto
# PATH. Installing the plugin from a marketplace puts bin/ on PATH only
# inside Claude Code sessions — a plain terminal has no idea `se` exists, or
# where. This tells them the exact command, using the real resolved plugin
# root, so they never have to work it out.
#
# Contract: stdout becomes session context, so this only ever prints a short
# block or nothing. It must never fail a session — every path exits 0, no
# python3 or non-POSIX dependency, and it tolerates an unset
# CLAUDE_PLUGIN_ROOT, an unset/unwritable HOME, and a missing PATH.
set -u

# No plugin root means no ln -s command to give — nothing useful to say.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0

# Does `se` resolve to something the user's own terminal will also find?
# Careful: an installed plugin's bin/ is on PATH *inside Claude Code
# sessions*, so a naive `command -v se` always succeeds here and the nudge
# would never fire for the people who need it most. A hit inside the plugin
# root proves only that the session can see it — not the terminal.
se_path=$(command -v se 2>/dev/null || true)
if [ -n "$se_path" ]; then
  case "$se_path" in
    "$CLAUDE_PLUGIN_ROOT"/*) : ;;   # session-only; still worth nudging
    *) exit 0 ;;                    # a real PATH entry — already linked
  esac
fi

config_dir="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}"
flag="$config_dir/.se-path-nudged"

# Already nudged once — a one-time hint must never become a nag.
[ -f "$flag" ] && exit 0

# Pick the first candidate dir that exists, is writable, and is already on
# PATH. HOME-relative candidates only make sense when HOME is set.
target=""
if [ -n "${HOME:-}" ]; then
  candidates="$HOME/.local/bin $HOME/bin /usr/local/bin"
else
  candidates="/usr/local/bin"
fi
for cand in $candidates; do
  case ":${PATH:-}:" in
    *":$cand:"*)
      if [ -d "$cand" ] && [ -w "$cand" ]; then
        target="$cand"
        break
      fi
      ;;
  esac
done

if [ -n "$target" ]; then
  printf 'The `se` command is not on your PATH yet. Link it in:\n'
  printf '  ln -s "%s/bin/se" "%s/se"\n' "$CLAUDE_PLUGIN_ROOT" "$target"
  printf 'Then run `rehash` (zsh) so open shells pick it up.\n'
else
  printf 'The `se` command is not on your PATH yet. Link it into a directory on your PATH, e.g.:\n'
  printf '  ln -s "%s/bin/se" ~/.local/bin/se\n' "$CLAUDE_PLUGIN_ROOT"
  printf '(create ~/.local/bin and add it to PATH first if it does not exist yet)\n'
  printf 'Then run `rehash` (zsh) so open shells pick it up.\n'
fi

# Best-effort flag write — a read-only/missing HOME must never break the
# nudge itself, so failures here are silently swallowed. Grouped so the
# 2>/dev/null covers even a redirection-setup failure on `: > "$flag"`
# (e.g. config_dir doesn't exist because mkdir -p above also failed).
{ mkdir -p "$config_dir" && : > "$flag"; } 2>/dev/null

exit 0
