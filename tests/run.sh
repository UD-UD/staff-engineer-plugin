#!/bin/bash
# Runs every tests/test-*.sh under /bin/bash and prints a pass/fail summary.
# Resolves the repo root from this script's own location, so it works from
# any cwd (`bash tests/run.sh`, `bash /abs/path/tests/run.sh`, ...).
set -u

here="$(cd "$(dirname "$0")" && pwd)"

total_pass=0
total_fail=0
any_fail=0

for f in "$here"/test-*.sh; do
  [ -e "$f" ] || continue
  name=$(basename "$f")

  out=$(/bin/bash "$f" 2>&1)
  rc=$?

  result_line=$(printf '%s\n' "$out" | grep -E '^RESULT pass=[0-9]+ fail=[0-9]+$' | tail -1)
  p=0
  fcount=0
  if [ -n "$result_line" ]; then
    p=$(printf '%s\n' "$result_line" | sed -E 's/^RESULT pass=([0-9]+) fail=([0-9]+)$/\1/')
    fcount=$(printf '%s\n' "$result_line" | sed -E 's/^RESULT pass=([0-9]+) fail=([0-9]+)$/\2/')
  fi
  total_pass=$((total_pass + p))
  total_fail=$((total_fail + fcount))

  status="PASS"
  if [ "$rc" -ne 0 ] || [ "$fcount" -gt 0 ] || [ -z "$result_line" ]; then
    status="FAIL"
    any_fail=1
  fi

  printf '%-24s %-4s pass=%d fail=%d\n' "$name" "$status" "$p" "$fcount"
  if [ "$status" = "FAIL" ]; then
    printf '%s\n' "$out" | sed 's/^/    /'
  fi
done

printf '\nTotal: pass=%d fail=%d\n' "$total_pass" "$total_fail"

if [ "$any_fail" -eq 1 ]; then
  exit 1
fi
exit 0
