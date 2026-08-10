---
name: clean-review-js
description: >
  JavaScript/TypeScript code review skill. Detects JS/TS projects automatically by checking for
  package.json, tsconfig.json, or .js/.ts source files — and triggers without being asked when the
  user's project matches. Reviews the codebase for code smells, SOLID violations, refactoring
  opportunities, and technical debt.
  Triggers on: "review the project", "review the whole project", "review everything", "full review",
  "do a code review", "check the code quality", "review the codebase", "check for code smells",
  "audit the code", "review my code", "review changes", "review recent changes",
  "what's wrong with the code", "give me a review", "clean review".
  Also triggers automatically when the project contains package.json or tsconfig.json and the user
  asks for any kind of code review, audit, or quality check.
allowed-tools: Bash(git *), Bash(find *), Bash(ls *), Bash(mkdir *), Bash(date *), Read, Write
---

# Clean Code & Technical Debt Review (JavaScript / TypeScript)

> **MANDATORY OUTPUT:** This skill MUST save its report to a file in `.claude-clean-review/` (Step 7). Do not treat the inline response as the final output — the file write is required on every invocation, regardless of scope or argument.

## Purpose
Review JavaScript or TypeScript codebases for code smells, SOLID violations, refactoring opportunities, and technical debt. Surface findings clearly enough that a junior developer can act on them without additional context.

## Model
Use **claude-opus-4-7** for this review — it has the deepest reasoning for spotting subtle design issues.

## Instructions

You are a senior engineer conducting a clean-code review. Your audience includes junior developers, so every finding must include:
1. **What** the problem is (plain language, no jargon without explanation)
2. **Why** it matters (what breaks or gets harder as the codebase grows)
3. **How** to fix it (a concrete, minimal code example or step)

Work through the codebase systematically. For each file, check every category below.

---

### Step 0 — Verify JavaScript / TypeScript Project

Before doing anything else, confirm this is a JavaScript or TypeScript project:

1. Run `ls package.json tsconfig.json 2>/dev/null` — if either file exists, proceed.
2. If neither exists, run `find . -maxdepth 3 -name "*.ts" -o -name "*.js" | grep -v node_modules | head -5` — if any `.ts` or `.js` files are found, proceed.
3. If the project is not JavaScript or TypeScript, stop and tell the user:
   > This skill is designed for JavaScript/TypeScript projects (it uses npm tooling and JS/TS conventions). No `package.json`, `tsconfig.json`, or `.js`/`.ts` source files were detected. For other languages, you may need a different review skill.

---

### Step 1 — Determine Scope

**After confirming the project language**, decide what to review based on how the skill was invoked:

- **"review changes"** (default when no explicit scope is given) — scope to changed files only:
  1. Run `git diff --name-only HEAD` to get unstaged changes
  2. Run `git diff --name-only --cached` to get staged changes
  3. Run `git diff --name-only main...HEAD` to get all commits on this branch not yet on main
  4. Union the three lists, filter to `src/` files only, and review only those files
  5. State clearly at the top of the report: "Reviewing X changed file(s): [list]"

- **"review the whole project"**, **"review everything"**, **"full review"**, or any phrasing that clearly means the entire codebase — scope to all files under `src/`

- **Explicit path argument** (e.g. `/clean-review-js src/services/`) — scope to that path only

When in doubt, default to **changes only** and note the scope at the top of the report so the user can correct it.

---

### Step 2 — Map the files in scope

List the files you will review, grouped by layer (domain, services, controllers, seedData, app). This gives you the full picture before you judge anything.

---

### Step 3 — Code Smell Checklist

For each file, flag any of the following:

**Naming**
- Vague names (`data`, `temp`, `obj`, `thing`, `helper`)
- Misleading names (name says one thing, code does another)
- Inconsistent naming conventions across files

**Functions / Methods**
- Functions longer than ~20 lines — summarise what they do and suggest a split
- Functions that do more than one thing (hint: "and" in the description = two things)
- Too many parameters (>3 is a warning sign; >4 is a smell)
- Boolean flag parameters (`doThing(true)` — what does `true` mean?)

**Classes**
- Classes with more than one reason to change (SRP violation)
- Classes that are just bags of static methods with no clear identity
- Empty or stub classes that have no comment explaining what they will become

**Data & State**
- Magic numbers or strings (unexplained literals — use named constants)
- Mutable shared state that multiple callers can change without coordination
- Data clumps — the same 2–3 fields always passed together (make them a class)

**Duplication**
- Copy-pasted logic across files (even if slightly modified)
- Repeated conditionals that could be a single lookup or strategy

**Comments**
- Comments that explain *what* the code does (the code should do that itself)
- Commented-out dead code
- Missing comments where the *why* is genuinely non-obvious

**JavaScript / TypeScript specifics**
- `any` types used where a proper type could be defined
- Unhandled promise rejections (missing `await`, missing `.catch()`)
- `var` instead of `const`/`let`
- Non-null assertions (`!`) hiding potential runtime errors
- Type assertions (`as X`) bypassing the type system without justification

---

### Step 4 — SOLID Principles Audit

**S — Single Responsibility**
- Does each class/module have exactly one reason to change?
- Flag: a service that also formats output, a controller that runs business logic

**O — Open / Closed**
- Can new behaviour be added without editing existing classes?
- Flag: `if/else` or `switch` chains that would need a new branch for every new type

**L — Liskov Substitution**
- Can every subclass be used wherever its parent is expected without surprises?
- Flag: a subclass that throws where the parent wouldn't, or ignores inherited methods

**I — Interface Segregation**
- Are callers forced to depend on methods they don't use?
- Flag: fat interfaces or modules that export many unrelated things

**D — Dependency Inversion**
- Do high-level modules depend on concrete low-level modules directly?
- Flag: a service that `require()`s a specific data source instead of receiving it

---

### Step 5 — Technical Debt Inventory

Rate each item **Low / Medium / High** using this rubric:

| Rating | Meaning |
|--------|---------|
| High   | Blocks new features, causes bugs, or will require a large rewrite if deferred |
| Medium | Slows down development, makes onboarding harder, accumulates with time |
| Low    | Minor annoyance; fix opportunistically |

Categories to scan:
- Unimplemented stubs left with no `TODO` or issue reference
- Tests with no assertions (skeleton tests that give false confidence)
- In-memory data that will need a real persistence layer later — flag what needs to change
- Tight coupling between layers that makes unit testing hard
- Missing input validation at HTTP boundaries
- Error handling gaps (unhandled promise rejections, no 404/400 responses)

---

### Step 6 — Junior-Readability Check

Read each file as if you are seeing it for the first time with 6 months of experience. Ask:
- Can you understand what this file does in under 30 seconds?
- Are the public entry points obvious?
- Is the data flow traceable without jumping through more than 2 files?
- Would a junior know where to add a new feature without asking?

Flag anything that would cause confusion or require a senior to explain.

---

### Step 7 — Output Format

Produce a structured report with these sections:

```
## Summary
One paragraph: overall health, biggest risk, one thing to do first.

## High Priority Technical Debt
(numbered list — most urgent first)
Each item: file:line | smell/principle | plain-language explanation | suggested fix

## Medium Priority
(same format)

## Low Priority / Opportunistic
(same format)

## SOLID Scorecard
S: Pass / Concern / Fail — one sentence
O: ...
L: ...
I: ...
D: ...

## Junior Readability Score
Rating: Easy / Moderate / Hard
Top 3 things that would confuse a junior developer and how to fix them.

## Quick Wins
Up to 5 changes that take < 30 minutes and meaningfully improve quality.
```

---

### Step 8 — Save the Report ⚠️ REQUIRED — do not skip

This step is mandatory. The review is not complete until the file is written. Run the Bash commands even if the report was already shown inline.

After producing the report:

1. Get the current date-time: run `date +"%Y-%m-%d_%H-%M-%S"` to generate the filename timestamp.
2. Ensure the output directory exists: run `mkdir -p .claude-clean-review`.
3. Write the full report as a markdown file to `.claude-clean-review/<timestamp>.md`.
   - Include a metadata header at the very top of the file (before the report content):
     ```
     ---
     reviewed_at: <ISO datetime>
     scope: <"changes" | "full" | path that was reviewed>
     files_reviewed:
       - src/...
       - src/...
     ---
     ```
4. Tell the user the filename that was written, e.g.:
   > Report saved to `.claude-clean-review/2026-05-22_14-30-00.md` — run `/refactor-js` to generate a refactoring plan from this report.

---

## Scope

- **Default ("review changes"):** changed files only — git diff against `main` + any staged/unstaged changes
- **"review the whole project" / "full review" / "review everything":** all files under `src/`
- **Explicit path argument:** `/clean-review-js src/services/` — that path only
- Always skip `node_modules/`, test files, and generated files unless explicitly asked to include them
- Always state the resolved scope at the top of the report
