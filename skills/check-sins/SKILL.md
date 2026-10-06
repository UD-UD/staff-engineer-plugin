---
name: check-sins
description: Check sins - "check sins", "attack this plan", "try to break this", "red-team this", or when plan/pr offer an adversarial pass. Delegates a plan or branch change to the inquisitor agent, which assumes it is broken and reports cited sins, what held, and a verdict.
---

# Check Sins

`review` assumes a competent author; this skill assumes the work is broken and
asks a fresh agent to prove how. It orchestrates only: the attack method and
the category definitions (Mortal sin, Venial sin, Unconfessed sin, Clean, and
the DAMNED / PENANCE / ABSOLVED verdict) live in the **inquisitor** agent.

## Process

### 1. Pick the mode and target

- **Plan mode** — a plan is being finalised: the plan text just presented, or
  `docs/plan/<flattened-branch>.md` (every character outside `[A-Za-z0-9._-]`
  in the branch name replaced by `-`, same rule as the `plan` skill).
- **Change mode** — branch work: `git diff <base>...HEAD` plus uncommitted
  work (`git diff`, `git diff --staged`, untracked files that belong to it).

If the user names a target, use it. If the mode is ambiguous, ask once. If the
target is empty (no plan, empty diff), say so and stop.

**Done when:** mode and a non-empty target are fixed.

### 2. Build the input and dispatch

Pass the **inquisitor** agent bundled with this plugin only the artifacts:

- the mode;
- the plan text or path, or the diff command;
- in change mode, the untracked paths that belong to the change (`git diff`
  never shows them, so without this list new files go unattacked);
- the plan file path, if one exists;
- the repo path.

Never pass the session's reasoning, the conversation, or why the author
believes it works. Fresh eyes are the point. If the agent is unavailable, say
coverage is reduced and stop there: do not substitute an inline self-review,
because the authoring session is the worst attacker of its own work.

**Done when:** the inquisitor's report is in hand, or the user has been told it
could not run.

### 3. Present

If the caller passed a Codex result path (`plan` and `pr` do, when the
user also took a Codex second opinion), wait for that run to be collected
and add its points after the sins, tagged `[codex]`, marking any that match
a sin as "both found it". A failed run is shown as `Codex failed: <reason>`.
The inquisitor never sees them; they are joined only here.

Hand the report to the `explainer` agent to publish as a plain-English page.
Give the user the link plus a terminal summary: the verdict line and one line
per sin (and per `[codex]` point). In step 4, `[codex]` points get the same
three choices as sins.

**Done when:** the user has the link and the summary.

### 4. The user chooses

For each sin, ask: **act**, **accept as risk**, or **reject**. One round,
numbered. Never fix, rewrite the plan, or dismiss a sin on your own.

- **Act** — plan mode: the plan is revised and re-presented. Change mode:
  fixes go through the normal flow.
- **Accept as risk** — written down where a later session finds it. Plan
  mode: into the presented plan's **Risks** section (saved with the plan on
  approval). Change mode: into an `## Accepted risks` section of the plan
  file, which `pr` reads for the PR's Risk section; with no plan file, hand
  it straight to the PR's Risk section if a PR is being prepared, and
  otherwise tell the user it is not saved anywhere.
- **Reject** — noted with the user's reason under `## Dismissed sins`: in
  the presented plan text (plan mode — nothing is written before approval)
  or in the plan file (change mode; with no plan file, tell the user it is
  not saved). Only if it also passes the three `docs/decisions.md` gates
  (as the `plan` skill applies them) does it go there too, as
  `**Dismissed sin — <sin>.** <why>` — never as `Rejected —`, which marks an
  idea not adopted and would make a later fix for this sin read as
  reopening a rejected idea. In plan mode, that entry waits until the plan
  is approved, like every other decision.

**Done when:** every sin has a recorded user decision.

### 5. Rounds

Re-run only when the user asks, after changes. At most 3 rounds on the same
target. If a round returns the same sins as the last, stop early and say so.

**Done when:** the user has no further round to request, or a cap or repeat
stopped it.

### 6. Stage gates

This skill reports and asks. It lifts no gate: plan approval and PR opening
stay with the user.
