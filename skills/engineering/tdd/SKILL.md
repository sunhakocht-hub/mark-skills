---
name: tdd
description: >
  Test-Driven Development workflow for implementing features, acceptance criteria, or user stories.
  Drives a strict Red -> Green -> Review -> Refactor loop, one acceptance criterion at a time, and
  stops to ask for explicit user confirmation before every step — writing a test, writing
  implementation code, running a review, applying a refactor, or moving to the next criterion.
  For JavaScript/TypeScript code, hands the review/refactor steps to the clean-review-js and
  refactor-js skills; for any other language, uses the built-in code-review and simplify skills.
  Triggers on: "implement this feature", "develop this feature", "build this user story",
  "implement this acceptance criteria", "implement this ticket", "use TDD", "test-driven
  development", "write the tests first", "implement this story", pasted acceptance criteria
  (Given/When/Then) or user story text ("As a ... I want ... so that ...").
  Also triggers automatically whenever the user asks to develop/implement/build a feature described
  by one or more acceptance criteria, regardless of whether TDD is mentioned by name.
---

# TDD (Test-Driven Development)

## Purpose
Implement a feature — whether it's a single acceptance criterion or a full user story with several — strictly test-first, one criterion at a time, with the user staying in control of every transition: test written, test run, implementation written, tests green, reviewed, refactored (or not), next criterion.

## Operating rule — confirm before every step

This is the point of the skill, not a formality. Before each of the following, stop and ask the user a direct question, and wait for an explicit go-ahead ("yes", "proceed", "go ahead", a correction, etc.) before continuing:

- writing a failing test
- running that test
- writing implementation code
- running the review skill
- applying a refactor
- moving on to the next acceptance criterion

Never collapse two of these into one turn. Never assume silence or a general "sounds good" earlier in the conversation covers a later step — each gate is its own ask. If the user explicitly says something like "stop asking, just go" or "skip confirmations for the rest of this", that waives the rule for the remainder of the session — state that you're doing so, then proceed without further gates.

---

### Step 0 — Parse the request and confirm scope

1. Determine whether the input is a **single acceptance criterion** or a **user story with multiple criteria** (numbered/bulleted lists, multiple Given/When/Then blocks, or an "As a ... I want ... so that ..." story followed by several criteria all count as multiple).
2. Normalize every criterion into Given/When/Then (or a clear bullet if Given/When/Then doesn't fit) and restate the full list back to the user.
3. Ask the user to confirm the breakdown and the order you'll work through them in. If they correct it, update and reconfirm before moving on.

Do not proceed to Step 1 until the criteria list is confirmed.

---

### Step 1 — Detect language and test tooling

1. Identify the language(s) involved based on where the feature will live (existing files/directories, or where the user says it belongs). If ambiguous, ask.
2. Work out the test command:
   - **JS/TS** — check `package.json` for a `test` script (or an existing `jest`/`vitest`/`mocha` config).
   - **Other languages** — infer the conventional runner (`pytest`, `go test ./...`, `cargo test`, `rspec`, etc.) from what's already in the repo.
3. State the detected language and test command, and ask the user to confirm it (or supply the right one) before any test is written.

A user story can span languages (e.g. a frontend criterion in TS, a backend criterion in Go) — redo this detection per criterion if the language changes.

---

### Step 2 — TDD loop (once per acceptance criterion, in the confirmed order)

Do not begin criterion N+1 until criterion N has completed 2a–2h **and** the user has confirmed moving on.

**2a. Confirm the criterion under test**
Restate it in Given/When/Then. Ask: "Ready to write a failing test for this criterion?"

**2b. RED — write the failing test**
Write the minimal test that encodes the criterion — no more than what this one criterion requires. Show it to the user. Ask before running it.

**2c. Confirm it fails for the right reason**
Run the test command and show the output. Verify the failure is the expected assertion failure, not a syntax error, import error, or crash. If it fails for the wrong reason, fix the test first — still ask before editing it. Ask: "Fails as expected — proceed to implementation?"

**2d. GREEN — write the minimal implementation**
Ask before writing any implementation code. Then write the smallest change that makes the test pass — no extra behavior, no speculative generalization, nothing the current test doesn't require.

**2e. Confirm green**
Run the **full** test suite, not just the new test — check for regressions. Show the results. Ask before moving to review.

**2f. REVIEW**
- If the files just changed are JavaScript/TypeScript, invoke the [`clean-review-js`](../clean-review-js/SKILL.md) skill, scoped to the files just changed (equivalent to running `/clean-review-js` against those files).
- Otherwise, invoke the built-in `code-review` skill at a medium effort level, scoped to the current diff.

Ask before invoking the review. Show the findings (or "no findings") when it returns.

**2g. REFACTOR — only if the review returned findings**
If the review found nothing, say so explicitly and skip straight to 2h. Do not refactor code the review didn't flag.

If it did find something, ask before acting on it, then:
- **JS/TS** — invoke [`refactor-js`](../refactor-js/SKILL.md), which reads the report `clean-review-js` just wrote to `.claude-clean-review/` (same handoff it uses standalone).
- **Other languages** — invoke the built-in `simplify` skill on the flagged files.

After the refactor, rerun the full test suite and show the results before considering the criterion done.

**2h. Confirm and advance**
State that the criterion is complete (test + implementation + review + optional refactor, all green). Ask: "Move on to the next acceptance criterion?" Do not start the next one without a yes.

---

### Step 3 — Final summary

Once every criterion is done, summarize:
- criteria covered (list)
- tests added (`file:line`)
- review findings per criterion, and what was/wasn't refactored and why
- final full test-suite status

---

## Scope / cross-skill handoff

- **JS/TS:** `clean-review-js` → `refactor-js`, using the same `.claude-clean-review/` file handoff those skills use when run standalone.
- **Other languages:** built-in `code-review` → built-in `simplify`.
- Language is detected fresh per criterion, so a single story can move between pairs if it spans a JS frontend and a non-JS backend.

## Operating rules (recap)

- Never batch multiple phases (write test + write implementation, or review + refactor) into a single turn without confirming between them.
- Never skip RED — a test must be shown failing, for the right reason, before any implementation is written.
- Never write more implementation than the current failing test requires.
- Never refactor code that the review step didn't flag.
- Confirmations default to on; only skip them if the user explicitly waives the rule for the session.
