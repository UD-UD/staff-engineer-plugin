---
name: debug
description: Debug this, diagnose, or anything broken, throwing, failing, flaky, or slow, and regressions between two known states. Builds a fast, deterministic feedback loop before any theory, then minimises, ranks hypotheses, instruments narrowly, and fixes with a regression test.
---

# Debugging Discipline

The prime rule: **no theory before a red command.** Every hard bug or
performance regression starts with a feedback loop that reproduces the
symptom on demand — everything else in this skill depends on that command
existing.

## Redact

Secrets never leave the loop. Show commands and their output with values
replaced by `<REDACTED>`, and build the feedback loop against environment
variables rather than pasted credentials.

## 1. Build a feedback loop before any theory

Before reading a line of source to form a theory, get one command that goes
red on this exact symptom — deterministic, seconds not minutes, runnable by
you alone. In order of preference:

1. A failing test at the nearest seam.
2. A curl/HTTP script hitting the failing endpoint.
3. A CLI run against a fixture, diffed against expected output.
4. A headless-browser script driving the failing flow.
5. Replaying a captured payload or request.
6. A throwaway harness that calls the suspect code directly.
7. A property or fuzz loop that finds the failing case itself.
8. A bisection harness over commits or inputs.
9. A differential run: old version vs new, same input, diffed output.

Then tighten it: make it faster, sharpen the assertion to the exact
symptom, pin time/seed/filesystem so every run is identical. If the bug is
non-deterministic, don't chase a clean repro — raise the reproduction rate
(loop N times, add load, narrow the timing window) until the loop is red
often enough to be useful.

If no loop can be built after genuinely trying the menu above, stop. List
what was tried and why each failed, then ask the user for a redacted
artifact (log, payload, stack trace) or access to the environment where it
reproduces. Catching yourself reading code to form a theory before this
command exists is exactly the failure this skill prevents.

**Done when:** one command reliably goes red on the exact symptom, in
seconds, with no manual steps.

## 2. Reproduce and minimise

Shrink the failing case — inputs, config, code path — until every remaining
element is load-bearing: removing it makes the loop go green. A minimal
case is usually most of the diagnosis.

**Done when:** nothing can be removed from the repro without losing the
failure.

## 3. Hypothesise

List 3–5 causes, ranked by likelihood, each with a falsifiable prediction:
"if X is the cause, changing Y makes the symptom disappear." Show the list
to the user before testing any of them — they can re-rank it in seconds if
they know something you don't. Don't block on a reply; proceed with your
own ranking if they're away.

**Done when:** every hypothesis on the list has a stated prediction, not
just a suspicion.

## 4. Instrument

Test one hypothesis, one variable, at a time — changing two things at once
destroys the result. Prefer a debugger or REPL over logs, and a handful of
targeted logs over logging everything.

Every debug log line carries a tag, `[DEBUG-xxxx]` (four hex characters
chosen once per debugging session, reused on every line you add that
session). This plugin's git guard refuses any commit while a tagged line
survives in the tree, so cleanup is a single grep and can't be forgotten.

<!-- Editors: keep the example above as [DEBUG-xxxx]; real hex digits here
would trip the guard on this repo. -->

A result that kills the hypothesis moves you to the next one on the list.
When every listed hypothesis is dead, go back to step 3 for a new ranked
list. First, if `se codex` (the plugin CLI) prints `codex: ready (...)` and
exits 0, offer a Codex diagnosis: "Get a Codex diagnosis? This sends the red
command, the minimised repro, and the ruled-out hypotheses with their
evidence to Codex (OpenAI), redacted." If it isn't ready, say nothing about
Codex.

If the user accepts:

- Everything sent passes the Redact rule first: no tokens, credentials, or
  customer data. Codex gets no current theory, only what was ruled out.
- Write the redacted input once to `scratchpad/codex-debug-input.md` and
  remove any old `scratchpad/codex-debug.md`. Then run
  `codex exec -s read-only -o scratchpad/codex-debug.md "<instruction to
  diagnose the bug using scratchpad/codex-debug-input.md>"`.
- Check the exit status, and read the result only if this run wrote it. On
  failure, say `Codex failed: <reason>` and fall back to step 3.
- Codex diagnoses only (read-only sandbox). Its answer becomes a new
  hypothesis on the step-3 list with a falsifiable prediction, tested here
  like any other. The fix still lands via step 5 with a regression test.

**Done when:** the loop's result confirms or kills the hypothesis under
test, and you know which. A confirmed hypothesis, whoever proposed it, moves
on to step 5.

## 5. Fix + regression test

Write the regression test before the fix, at a seam that exercises the real
bug pattern — not one that merely happens to pass once the code is fixed.
If no seam can exercise the real pattern, that gap is itself a finding:
report it rather than shipping a test that doesn't cover the bug. Hand the
rest of the test discipline to `/se:test`.

**Done when:** the regression test is red before the fix and green after,
at a seam that would have caught the original bug.

## 6. Cleanup

Before calling the bug closed, confirm all of:

- The original feedback loop from phase 1 is green.
- The regression test is green (or the missing seam is documented).
- `git grep -nE '\[DEBUG-[0-9a-fA-F]{4}\]'` returns nothing. (A bare
  `DEBUG-` search also hits every file that documents the convention, this
  one included.)
- Any throwaway harness from phase 1 is removed.
- The commit message states the confirmed hypothesis, not just "fix bug".

**Done when:** every item above holds and the confirmed hypothesis is
written down.
