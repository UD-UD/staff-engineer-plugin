#!/bin/bash
# Exercises hooks/scripts/se-path-nudge.sh: run it under various fake HOME /
# PATH / CLAUDE_PLUGIN_ROOT setups and assert what it prints and exits.
# Never modifies se-path-nudge.sh; only ever runs it with a controlled env.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
nudge="$root/hooks/scripts/se-path-nudge.sh"

pass=0
fail=0

ok() { pass=$((pass + 1)); printf 'ok - %s\n' "$1"; }
notok() { fail=$((fail + 1)); printf 'not ok - %s\n' "$1"; }

tmpdir=$(mktemp -d)
trap 'chmod -R u+w "$tmpdir" 2>/dev/null; rm -rf "$tmpdir"' EXIT

# A minimal PATH with no `se` on it anywhere, plus a directory to hold a
# fake `se` executable for the "already on PATH" case.
nobin="$tmpdir/nobin"
mkdir -p "$nobin"
withbin="$tmpdir/withbin"
mkdir -p "$withbin"
cat > "$withbin/se" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$withbin/se"

plugin_root="$tmpdir/plugin-root"
mkdir -p "$plugin_root/bin"

# se-path-nudge.sh itself shells out to mkdir/: internally — an empty PATH
# would break those, not just the `se` lookup we're trying to control. Keep
# real system dirs on PATH (no `se` binary lives there) alongside the test
# dirs so the script's own internals still work.
sys_path="/usr/bin:/bin:/usr/sbin:/sbin"

# --- Case 1: no se on PATH, fresh HOME -> prints the nudge, exits 0 --------
home1="$tmpdir/home1"
mkdir -p "$home1"
out=$(HOME="$home1" CLAUDE_PLUGIN_ROOT="$plugin_root" PATH="$nobin:$sys_path" "$nudge")
rc=$?
if [ "$rc" -eq 0 ]; then ok "fresh HOME: exits 0"; else notok "fresh HOME: exits 0 (got $rc)"; fi
if printf '%s' "$out" | grep -q 'ln -s'; then ok "fresh HOME: prints ln -s"; else notok "fresh HOME: prints ln -s (got: $out)"; fi
if printf '%s' "$out" | grep -qF "$plugin_root"; then
  ok "fresh HOME: prints the given CLAUDE_PLUGIN_ROOT"
else
  notok "fresh HOME: prints the given CLAUDE_PLUGIN_ROOT (got: $out)"
fi

# --- Case 2: run again with the same HOME -> flag suppresses it ------------
out2=$(HOME="$home1" CLAUDE_PLUGIN_ROOT="$plugin_root" PATH="$nobin:$sys_path" "$nudge")
rc2=$?
if [ "$rc2" -eq 0 ]; then ok "second run: exits 0"; else notok "second run: exits 0 (got $rc2)"; fi
if [ -z "$out2" ]; then ok "second run: prints nothing"; else notok "second run: prints nothing (got: $out2)"; fi

# --- Case 3: se already on PATH -> prints nothing, exits 0 -----------------
home3="$tmpdir/home3"
mkdir -p "$home3"
out3=$(HOME="$home3" CLAUDE_PLUGIN_ROOT="$plugin_root" PATH="$withbin:$nobin:$sys_path" "$nudge")
rc3=$?
if [ "$rc3" -eq 0 ]; then ok "se on PATH: exits 0"; else notok "se on PATH: exits 0 (got $rc3)"; fi
if [ -z "$out3" ]; then ok "se on PATH: prints nothing"; else notok "se on PATH: prints nothing (got: $out3)"; fi

# --- Case 3b: the ONLY se on PATH is the plugin's own bin/ -----------------
# Claude Code puts an installed plugin's bin/ on the session PATH, so `se`
# resolves in here while the user's terminal still can't find it. That is
# exactly who the nudge is for, so it must still fire.
home3b="$tmpdir/home3b"
mkdir -p "$home3b" "$plugin_root/bin"
printf '#!/bin/sh\nexit 0\n' > "$plugin_root/bin/se"
chmod +x "$plugin_root/bin/se"
out3b=$(HOME="$home3b" CLAUDE_PLUGIN_ROOT="$plugin_root" PATH="$plugin_root/bin:$nobin:$sys_path" "$nudge")
rc3b=$?
if [ "$rc3b" -eq 0 ]; then ok "plugin-only se: exits 0"; else notok "plugin-only se: exits 0 (got $rc3b)"; fi
case "$out3b" in
  *"ln -s"*) ok "plugin-only se on PATH still nudges" ;;
  *) notok "plugin-only se on PATH still nudges (got: $out3b)" ;;
esac

# --- Case 4: CLAUDE_PLUGIN_ROOT unset -> prints nothing, exits 0, no crash -
home4="$tmpdir/home4"
mkdir -p "$home4"
out4=$(env -u CLAUDE_PLUGIN_ROOT HOME="$home4" PATH="$nobin:$sys_path" "$nudge")
rc4=$?
if [ "$rc4" -eq 0 ]; then ok "no CLAUDE_PLUGIN_ROOT: exits 0"; else notok "no CLAUDE_PLUGIN_ROOT: exits 0 (got $rc4)"; fi
if [ -z "$out4" ]; then ok "no CLAUDE_PLUGIN_ROOT: prints nothing"; else notok "no CLAUDE_PLUGIN_ROOT: prints nothing (got: $out4)"; fi

# --- Case 5: read-only HOME -> still nudges, still exits 0 -----------------
home5="$tmpdir/home5"
mkdir -p "$home5"
chmod 555 "$home5"
out5=$(HOME="$home5" CLAUDE_PLUGIN_ROOT="$plugin_root" PATH="$nobin:$sys_path" "$nudge")
rc5=$?
chmod u+w "$home5"
if [ "$rc5" -eq 0 ]; then ok "read-only HOME: exits 0"; else notok "read-only HOME: exits 0 (got $rc5)"; fi
if printf '%s' "$out5" | grep -q 'ln -s'; then
  ok "read-only HOME: still prints the nudge"
else
  notok "read-only HOME: still prints the nudge (got: $out5)"
fi

# --- Case 6: ~/.local/bin exists, writable, on PATH -> that's the target ---
home6="$tmpdir/home6"
localbin="$home6/.local/bin"
mkdir -p "$localbin"
out6=$(HOME="$home6" CLAUDE_PLUGIN_ROOT="$plugin_root" PATH="$localbin:$nobin:$sys_path" "$nudge")
rc6=$?
if [ "$rc6" -eq 0 ]; then ok "~/.local/bin on PATH: exits 0"; else notok "~/.local/bin on PATH: exits 0 (got $rc6)"; fi
if printf '%s' "$out6" | grep -qF "$localbin/se"; then
  ok "~/.local/bin on PATH: printed target is ~/.local/bin"
else
  notok "~/.local/bin on PATH: printed target is ~/.local/bin (got: $out6)"
fi

printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
