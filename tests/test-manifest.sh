#!/bin/bash
# Deterministic checks of the plugin's own manifests and skill/agent
# frontmatter: plugin.json, marketplace.json and hooks.json parse as JSON;
# every skills/*/SKILL.md and agents/*.md carries the frontmatter Claude
# Code needs (and skill names are unique); every ${CLAUDE_PLUGIN_ROOT} path a
# hook references resolves to a real file (executable, under hooks/scripts);
# no [DEBUG-<hex>] tag literal survives anywhere in the tree. A negative
# fixture proves the frontmatter checks can actually fail.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

pass=0
fail=0

ok() { pass=$((pass + 1)); printf 'ok - %s\n' "$1"; }
notok() { fail=$((fail + 1)); printf 'not ok - %s\n' "$1"; }

# --- check 1: .claude-plugin/plugin.json ------------------------------------

check_plugin_json() { # ROOT
  local check_root="$1"
  local f="$check_root/.claude-plugin/plugin.json"
  if python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$f" >/dev/null 2>&1; then
    ok "plugin.json parses as JSON"
  else
    notok "plugin.json parses as JSON"
    return
  fi
  local key val
  for key in name version description; do
    val=$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get(sys.argv[2]) or "")
' "$f" "$key" 2>/dev/null)
    if [ -n "$val" ]; then
      ok "plugin.json has non-empty $key"
    else
      notok "plugin.json has non-empty $key"
    fi
  done
}

# --- check 2: .claude-plugin/marketplace.json -------------------------------

check_marketplace_json() { # ROOT
  local check_root="$1"
  local f="$check_root/.claude-plugin/marketplace.json"
  if python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$f" >/dev/null 2>&1; then
    ok "marketplace.json parses as JSON"
  else
    notok "marketplace.json parses as JSON"
  fi
}

# --- check 3: hooks/hooks.json ----------------------------------------------

check_hooks_json() { # ROOT
  local check_root="$1"
  local f="$check_root/hooks/hooks.json"
  if python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$f" >/dev/null 2>&1; then
    ok "hooks.json parses as JSON"
  else
    notok "hooks.json parses as JSON"
    return
  fi
  if python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if isinstance(d.get("hooks"), dict) else 1)
' "$f" >/dev/null 2>&1; then
    ok "hooks.json has a hooks object"
  else
    notok "hooks.json has a hooks object"
  fi
}

# --- checks 4 & 5: skill / agent frontmatter --------------------------------
#
# Emits one "STATUS|message[|detail]" line per assertion on stdout; the
# caller folds each line into ok/notok. Generic over whatever directories
# exist under skills/ or agents/ - never a hardcoded list.

run_frontmatter_checks() { # ROOT kind(skills|agents)
  python3 - "$1" "$2" <<'PY'
import glob, os, re, sys

root, kind = sys.argv[1], sys.argv[2]


def parse_frontmatter(path):
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        return None
    fields = {}
    key = None
    for line in lines[1:end]:
        m = re.match(r'^([A-Za-z0-9_-]+):\s*(.*)$', line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            if len(val) >= 2 and val[0] == val[-1] and val[0] in ('"', "'"):
                val = val[1:-1]
            fields[key] = val
        elif key is not None:
            fields[key] = (fields[key] + " " + line.strip()).strip()
    return fields


def emit(status, msg, detail=""):
    if detail:
        print("%s|%s|%s" % (status, msg, detail))
    else:
        print("%s|%s" % (status, msg))


if kind == "skills":
    pattern = os.path.join(root, "skills", "*", "SKILL.md")
    seen = {}
    for path in sorted(glob.glob(pattern)):
        dir_name = os.path.basename(os.path.dirname(path))
        label = "skills/%s/SKILL.md" % dir_name
        fm = parse_frontmatter(path)
        if fm is None:
            emit("FAIL", "%s has a --- frontmatter block" % label, "missing or malformed")
            continue
        emit("OK", "%s has a --- frontmatter block" % label)
        name = fm.get("name", "")
        if name == dir_name:
            emit("OK", "%s name matches its directory" % label)
        else:
            emit("FAIL", "%s name matches its directory" % label,
                 "got '%s' want '%s'" % (name, dir_name))
        desc = fm.get("description", "")
        if desc:
            emit("OK", "%s description is non-empty" % label)
        else:
            emit("FAIL", "%s description is non-empty" % label)
        if name:
            seen.setdefault(name, []).append(label)
    dupes = dict((k, v) for k, v in seen.items() if len(v) > 1)
    if dupes:
        for name, labels in dupes.items():
            emit("FAIL", "skill name '%s' is unique" % name, "used by %s" % ", ".join(labels))
    else:
        emit("OK", "skill names are unique")
elif kind == "agents":
    pattern = os.path.join(root, "agents", "*.md")
    for path in sorted(glob.glob(pattern)):
        label = "agents/%s" % os.path.basename(path)
        fm = parse_frontmatter(path)
        if fm is None:
            emit("FAIL", "%s has a --- frontmatter block" % label, "missing or malformed")
            continue
        emit("OK", "%s has a --- frontmatter block" % label)
        for key in ("name", "description", "tools"):
            val = fm.get(key, "")
            if val:
                emit("OK", "%s %s is non-empty" % (label, key))
            else:
                emit("FAIL", "%s %s is non-empty" % (label, key))
PY
}

check_frontmatter() { # ROOT kind(skills|agents) mode(real|fixture)
  local check_root="$1" kind="$2" mode="$3"
  local local_pass=0
  local local_fail=0
  local status msg detail line
  while IFS='|' read -r status msg detail; do
    [ -n "$status" ] || continue
    line="$msg"
    [ -n "$detail" ] && line="$msg ($detail)"
    if [ "$status" = "OK" ]; then
      local_pass=$((local_pass + 1))
      if [ "$mode" = "real" ]; then ok "$line"; else printf 'ok - [fixture] %s\n' "$line"; fi
    else
      local_fail=$((local_fail + 1))
      if [ "$mode" = "real" ]; then notok "$line"; else printf 'not ok - [fixture] %s\n' "$line"; fi
    fi
  done < <(
    run_frontmatter_checks "$check_root" "$kind"
  )
  LAST_CHECK_PASS=$local_pass
  LAST_CHECK_FAIL=$local_fail
}

# --- check 6: every ${CLAUDE_PLUGIN_ROOT}/<path> a hook command uses -------

check_hook_paths() { # ROOT
  local check_root="$1"
  local status msg detail line
  while IFS='|' read -r status msg detail; do
    [ -n "$status" ] || continue
    line="$msg"
    [ -n "$detail" ] && line="$msg ($detail)"
    if [ "$status" = "OK" ]; then ok "$line"; else notok "$line"; fi
  done < <(
    python3 - "$check_root" <<'PY'
import json, os, re, sys

root = sys.argv[1]
f = os.path.join(root, "hooks", "hooks.json")


def emit(status, msg, detail=""):
    if detail:
        print("%s|%s|%s" % (status, msg, detail))
    else:
        print("%s|%s" % (status, msg))


try:
    with open(f, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    emit("FAIL", "hooks.json readable for path checks", str(exc))
    sys.exit(0)

commands = []


def walk(node):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "command" and isinstance(v, str):
                commands.append(v)
            else:
                walk(v)
    elif isinstance(node, list):
        for item in node:
            walk(item)


walk(data)

pattern = re.compile(r'\$\{CLAUDE_PLUGIN_ROOT\}(/[^\s"\x27]+)')
found_any = False
for cmd in commands:
    for m in pattern.finditer(cmd):
        found_any = True
        rel = m.group(1).lstrip("/")
        target = os.path.join(root, rel)
        label = "hook path %s" % rel
        if os.path.isfile(target):
            emit("OK", "%s exists" % label)
            if rel.startswith("hooks/scripts/"):
                if os.access(target, os.X_OK):
                    emit("OK", "%s is executable" % label)
                else:
                    emit("FAIL", "%s is executable" % label)
        else:
            emit("FAIL", "%s exists" % label)

if not found_any:
    emit("FAIL", "hooks.json references at least one CLAUDE_PLUGIN_ROOT path", "none found")
PY
  )
}

# --- check 7: no [DEBUG-<hex>] tag literal survives -------------------------
#
# Built via printf so this file never contains the literal debug-tag shape.

check_no_debug_tag() { # ROOT
  local check_root="$1"
  local debug_pattern
  debug_pattern=$(printf '\\[DEBUG-%s\\]' '[0-9a-f]{4}')
  local hits
  hits=$(git -C "$check_root" grep -lE --untracked -e "$debug_pattern" -- . 2>/dev/null)
  if [ -z "$hits" ]; then
    ok "no debug-tag literal survives anywhere in the tree"
  else
    notok "no debug-tag literal survives anywhere in the tree (found in: $hits)"
  fi
}

# --- negative fixture: proves checks 4 & 5 can fail -------------------------

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fixture_root="$tmpdir/badplugin"
mkdir -p "$fixture_root/skills/bad"
cat > "$fixture_root/skills/bad/SKILL.md" <<'EOF'
---
name: wrong
---

# Bad skill

Wrong name, no description.
EOF

mkdir -p "$fixture_root/agents"
cat > "$fixture_root/agents/x.md" <<'EOF'
---
name: x
description: Missing its tools field.
---

# x

Agent body.
EOF

# --- run all checks against the real plugin root ----------------------------

check_plugin_json "$root"
check_marketplace_json "$root"
check_hooks_json "$root"
check_frontmatter "$root" skills real
check_frontmatter "$root" agents real
check_hook_paths "$root"
check_no_debug_tag "$root"

# --- run the negative fixture (checks 4 & 5 only) ---------------------------
#
# Captures the sub-check's own failure count rather than folding it into the
# suite's global counters, so a deliberately-broken fixture still leaves the
# suite green.

check_frontmatter "$fixture_root" skills fixture
if [ "$LAST_CHECK_FAIL" -gt 0 ]; then
  ok "negative fixture: bad skill frontmatter is reported as failing ($LAST_CHECK_FAIL check(s))"
else
  notok "negative fixture: bad skill frontmatter is reported as failing"
fi

check_frontmatter "$fixture_root" agents fixture
if [ "$LAST_CHECK_FAIL" -gt 0 ]; then
  ok "negative fixture: agent missing tools is reported as failing ($LAST_CHECK_FAIL check(s))"
else
  notok "negative fixture: agent missing tools is reported as failing"
fi

printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
