---
name: plan-story
description: >
  Agentic planning workflow for a user story or ticket (Jira/Linear-style export, an "As a ... I want
  to ... so that ..." story, or a standalone acceptance-criteria list). A dedicated planning agent
  breaks the story into an ordered implementation plan mapped to Given/When/Then acceptance criteria;
  a separate review agent critiques that plan for coverage, scope, sequencing, and testability before
  it is discussed and approved directly with the user. Once approved, every implementation task in
  the plan is executed through the tdd skill, one task at a time, in direct conversation with the
  user — this skill never writes implementation code itself.
  Triggers on: "plan this story", "plan this ticket", "create an implementation plan", "break down
  this user story", "plan out this feature", "plan the acceptance criteria", "plan and review this
  story", a pasted Jira/Linear ticket export, or a user story followed by an acceptance-criteria table
  and/or a tasks checklist.
  Also triggers automatically when the user pastes or points at a ticket file containing
  "As a ... I want ... so that ...", a Given/When/Then acceptance-criteria table, or a tasks
  checklist, and is asking for a plan rather than asking to implement directly (a direct
  implementation request with no planning ask should go straight to the tdd skill).
allowed-tools: Agent, Skill, Read, Write, Bash(mkdir *), Bash(date *), Bash(ls *), Bash(find *), Bash(git *)
---

# Plan Story

## Purpose
Turn a user story, ticket, or acceptance-criteria set into an implementation plan the team can trust — produced by a dedicated planning agent, stress-tested by a separate review agent, and then approved with the user before any code is written. Once approved, every implementation task in the plan is carried out through the [`tdd`](../tdd/SKILL.md) skill, never written directly by this skill.

## Model
Use **claude-opus-4-7** for the orchestrating turn, and pass the equivalent reasoning-tier `model` override on both the planning and review `Agent` calls in Phases 1–2 — decomposing a story into a sequenced, independently-testable plan, and then critiquing that plan for gaps, both need the deepest reasoning available.

---

## Operating rule — two independent agents, one human gate, implementation stays in-thread

- The **planning agent** (Phase 1) and the **review agent** (Phase 2) are separate `Agent` tool calls. The review agent must not be a continuation of the planning agent's run and must not see the planning agent's reasoning — only the original story and the finished draft plan. That separation is what keeps the review honest.
- **The plan is approved by the user, never by an agent.** After the review agent reports back, the plan is walked through and approved directly with the user (Phase 3). The review agent's output is critique to react to, not a sign-off.
- **Implementation (Phase 5) is not delegated to a subagent.** It runs in this same conversation, invoking the [`tdd`](../tdd/SKILL.md) skill directly. `tdd` is built around stopping to confirm with the user before every single step (write test, run test, implement, review, refactor, advance) — that only works in direct conversation. Spawning a subagent per task would force those gates through an extra relay or, worse, tempt `tdd` to run ungated in the background, which breaks its contract.
- **This skill never writes implementation code itself.** Every task in the approved plan is executed by invoking `tdd`. If the user's actual intent is "just implement this now" with no planning wanted, confirm whether they want to skip straight to `tdd` instead.

---

### Phase 0 — Verify there's a plannable story

Check the input (pasted text, or a file the user points you at) for at least one of:
- An "As a ... I want to ... so that ..." (or equivalent) story statement
- A Given/When/Then or bullet acceptance-criteria list
- A tasks checklist

If it's just "implement X" with nothing to plan from, ask whether they want it planned first or handed straight to [`tdd`](../tdd/SKILL.md).

If given a file path (e.g. a Jira/Linear export), `Read` it in full before proceeding — don't work from a partial read.

Restate your understanding of: the story/stories, the acceptance criteria, any notes/constraints, and the out-of-scope list. Ask the user to confirm you've read it correctly before spawning any agent.

Do not proceed to Phase 1 until the user confirms.

---

### Phase 1 — Planning agent

Spawn an `Agent` call (foreground — you need its result before continuing), briefed as a software architect. Since it starts with no memory of this conversation, give it everything self-contained:

- The full story text verbatim (or the file path to read)
- The repo's working directory, so it can inspect existing conventions (similar features already built, table/migration patterns, feature-toggle patterns already in use) before proposing new ones instead of guessing
- Instructions to produce an **ordered task list**, where every task:
  - has a short title and states the files/layers it touches (backend/frontend/db/etc.)
  - is mapped to one or more acceptance criteria, normalized to Given/When/Then — this is what `tdd` will consume directly, one task at a time
  - is small enough to be implemented and tested independently — if `tdd` couldn't take it as a single red/green loop, split it further
  - explicitly respects the story's "Out of scope" section (call out what it's deliberately not doing, and why)
  - notes dependencies on earlier tasks (e.g. "needs the configuration table added in task 3")
- Instructions to reconcile the plan against any existing "Tasks checklist" in the ticket — every checklist item must map to a plan task, or be explicitly called out as already covered or out of scope

Use `subagent_type: "Plan"` — it has read/explore tools and no write access, which matches this phase's boundary exactly: plan, don't touch code.

---

### Phase 2 — Review agent

Spawn a second, independent `Agent` call (foreground) with `subagent_type: "general-purpose"`. Give it, self-contained:

- The original story text (not the planning agent's reasoning — it hasn't seen this conversation)
- The draft plan produced in Phase 1
- This review checklist:

| Check | Look for |
|---|---|
| **Coverage** | Every acceptance criterion has a task. Every ticket checklist item is represented, or explicitly deferred with a reason. |
| **Scope discipline** | No task touches anything listed under "Out of scope". |
| **Sequencing** | Tasks are ordered so each is independently implementable; dependencies are explicit and don't form a cycle. |
| **Testability** | Each task's Given/When/Then is concrete enough to hand straight into a TDD loop — flag anything still vague ("improve the UI") that isn't yet a testable criterion. |
| **Simplicity** | Is there a simpler way to satisfy the same acceptance criteria? Flag over-engineered tasks. |
| **Codebase fit** | Does a task duplicate or conflict with something that already exists? (it should actually check the repo, not assume) |
| **Risks/unknowns** | Anything the plan glosses over — migrations, the default state of a new feature toggle, security, backward compatibility |

Instruct it to return **findings only, not a rewritten plan** — one line per finding: which task, which check, what's wrong, suggested fix. If a category has no issues, it should say so explicitly rather than omit it, so the user can see the review was thorough rather than incomplete.

---

### Phase 3 — Review and approve with the user

This is a human gate, not an agent step. Present to the user:
1. The draft plan (Phase 1)
2. The review agent's findings (Phase 2), organized by task

Walk through the findings with the user. For each one, they can accept the fix, reject it (state why), or propose something else. Update the plan directly as you go — don't re-spawn the planning agent for small edits.

If the changes are substantial (re-sequencing, splitting/merging several tasks, or a finding that raises a scope question you can't resolve without re-exploring the codebase), re-run Phase 1 with the feedback folded in, then Phase 2 again on the revised draft.

Do not proceed to Phase 4 until the user explicitly approves the plan as it stands.

---

### Phase 4 — Save the approved plan

1. `mkdir -p .claude-story-plan`
2. Get a timestamp: `date +"%Y-%m-%d_%H-%M-%S"`
3. Write the approved plan to `.claude-story-plan/<timestamp>.md` with a metadata header:
   ```
   ---
   story: <ticket id/title>
   planned_at: <ISO datetime>
   approved_at: <ISO datetime>
   ---
   ```
4. Body: the full task list, each with its Given/When/Then, files/layers, dependencies, and status (`[ ]` not started). Include the resolved review findings so the record shows what was raised and what was decided.
5. Tell the user the filename that was written.

---

### Phase 5 — Implement every task through `tdd` (in-thread, no subagent)

**No exceptions: every task is implemented by invoking [`tdd`](../tdd/SKILL.md) directly in this conversation, never by writing code directly in this skill and never by delegating the loop to a subagent.**

For each task, in the plan's order:

1. Restate the task and its Given/When/Then. Confirm any dependency tasks are already done.
2. Ask: "Ready to start this task via TDD?"
3. Invoke the `tdd` skill, handing it this task's Given/When/Then as its input (equivalent to pasting that criterion at `tdd` Step 0). Let `tdd` run its own full confirm-gated Red → Green → Review → Refactor loop for this task, in direct conversation with the user — do not shortcut, duplicate, or pre-empt any of its gates.
4. When `tdd` reports the task's criteria are done, mark the task `[x]` in the saved plan file.
5. Ask before moving to the next task.

If a task turns out to need re-splitting once `tdd` gets into it (the criterion was bigger than it looked), pause, update the plan file, and confirm the new breakdown with the user before continuing.

---

### Phase 6 — Final summary

Once every task is complete:
- List tasks completed, each with the criteria covered and `file:line` of key tests/implementation
- Confirm every "Out of scope" item was in fact left untouched
- State the plan file location for the audit trail
- Note anything deferred or left for follow-up

---

## Scope / cross-skill handoff

- Planning agent: `subagent_type: "Plan"` (read-only architecture reasoning).
- Review agent: `subagent_type: "general-purpose"` (needs to check the plan against the actual codebase).
- Implementation: every task hands off to [`tdd`](../tdd/SKILL.md) in-thread — never via a subagent — which owns its own JS/TS (`clean-review-js` → `refactor-js`) vs. other-language (`code-review` → `simplify`) split per criterion.
- Plan records live in `.claude-story-plan/<timestamp>.md`, following the same file-based handoff pattern as `.claude-clean-review/`.

## Operating rules (recap)

- Planning agent and review agent are separate `Agent` calls; the reviewer never inherits the planner's context.
- The plan is approved by the user, never by an agent.
- Never write implementation code directly — every task goes through `tdd`, run in-thread.
- Never start Phase 5 before the user has approved the plan in Phase 3.
- Never batch two phases into one turn without the relevant confirmation.
