---
name: test
description: Use whenever changing behavior, fixing a bug, or dealing with failing tests. Enforces testing discipline - every behavior change ships with a test, bug fixes start with a failing regression test, the right test level is chosen, and tests are never weakened to make them pass.
---

# Testing Discipline

Tests are the contract. The prime rule: **when a test fails, fix the code, not
the test.** A test may only change when the requirement it encodes has
genuinely changed — and then you say so explicitly.

## Define success before you start

Transform every task into a verifiable goal before writing code:

- "Add validation" → "Write tests for invalid inputs, then make them pass."
- "Fix the bug" → "Write a test that reproduces it, then make it pass."
- "Refactor X" → "Ensure tests pass before and after, unchanged."

For multi-step work, state the plan with a verification per step
(`1. [step] → verify: [check]`), then loop until every check passes. "Done"
means verified, not written.

## Rules

### Every behavior change ships with a test

- New feature → tests for the new behavior, including at least one edge case
  (empty, null, boundary, error path), not just the happy path.
- Bug fix → **regression test first.** Write the test that reproduces the bug,
  run it, watch it fail for the expected reason, then fix the code, then watch
  it pass. A fix without a red-then-green test is unverified.
- Pure refactor → no new tests required, but the existing suite must pass
  before and after, unchanged.

### Choose the right level

Use the **lowest level that can catch the defect** — lower levels are faster,
more precise, and less flaky:

- **Unit** — pure logic, formatting, validation, state transitions. No IO.
- **Integration** — module boundaries, database access, adapters, anything
  crossing a process or persistence boundary.
- **End-to-end** — complete user journeys only; the expensive last resort,
  not the default.

Follow the project's existing test layout, runner, and naming conventions —
discover them (look at neighboring test files) before writing anything.

### Never write a weak test

A test that cannot fail is worse than no test — it certifies nothing and
costs maintenance forever.

- Assert specific outcomes (values, states, error types), never just
  "it ran without crashing" or assertion-free execution.
- Don't mock the unit under test, and don't mock so much that the test only
  exercises the mocks.
- Cover the edge and error paths the change actually introduces, not a
  single happy path for show.

### Never weaken a test to get green

All of these are forbidden ways to make a failing test pass:

- Broadening an assertion (`assertEqual` → `assertTrue`, exact → substring).
- Deleting, skipping, or marking a test as expected-failure.
- Adding sleeps or retries to paper over a race the code actually has.
- Mocking out the very unit the test exists to exercise.
- Changing test fixtures/expected values to match buggy output.

If you believe a test itself is wrong, stop and tell the user which test, what
it currently asserts, and why you think the requirement changed. Get agreement
before touching it.

### Run and report honestly

- Run the relevant tests before declaring any change done. Prefer the narrow
  set first (changed module), then the broader suite if the project's is fast
  enough.
- Report the real outcome with the actual failure output when something fails.
  Never describe a change as working when its tests were not run.
