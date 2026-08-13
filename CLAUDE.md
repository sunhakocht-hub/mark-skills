# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal collection of Claude Code skills (`SKILL.md` files), organized so they can be symlinked into `~/.claude/skills` for use across other projects. There is no application code here — the "product" is the skill definitions themselves.

## Installing / linking skills

```bash
./scripts/link-skills.sh
```

This finds every `SKILL.md` under `skills/`, and symlinks each skill's containing directory into `~/.claude/skills/<skill-name>`, so the skills become available to the local Claude CLI globally. Re-run after adding, renaming, or removing a skill.

- Skips any skill under a `node_modules/`, `deprecated/`, `in-progress/`, or `personal/` path segment — use those directory names to keep a skill out of the linked set while it's still in the repo.
- If `~/.claude/skills` is itself a symlink pointing back into this repo, the script refuses to run (to avoid writing symlinks into the repo's own working copy). Remove the stray symlink and re-run.
- The skill's directory name (not the `name:` frontmatter field) becomes the link name in `~/.claude/skills/`.

There is no build, lint, or test step — these are prompt/instruction files, not executable code.

## Repository layout

```
skills/
  engineering/
    clean-review-js/SKILL.md
    refactor-js/SKILL.md
    debug-gha/SKILL.md
    tdd/SKILL.md
scripts/
  link-skills.sh
```

Skills are grouped into category directories under `skills/` (currently just `engineering/`). Add new skills as `skills/<category>/<skill-name>/SKILL.md`.

## Anatomy of a SKILL.md

Every skill file has YAML frontmatter followed by the skill's instructions:

```yaml
---
name: skill-name              # must match the directory name
description: >                # dense, keyword-rich — this is what triggers
                               # auto-invocation, so pack in explicit trigger
                               # phrases the user is likely to type
allowed-tools: Bash(git *), Bash(find *), Read, Write   # optional; scopes
                                                          # what the skill can invoke
---
```

Conventions used consistently across the existing skills:

- **Auto-trigger via description, not just slash command.** Descriptions list explicit trigger phrases (e.g. "review the project", "full review") and detection heuristics (e.g. "project contains `package.json` or `tsconfig.json`") so the skill fires without the user typing `/skill-name`.
- **Verify applicability first.** `clean-review-js` and `refactor-js` both open with a "Step/Phase 0" that checks for `package.json`/`tsconfig.json`/`.js`/`.ts` files and bails out with a clear message if the project doesn't match, rather than silently proceeding.
- **Numbered Steps/Phases, not free-form prose.** Instructions are broken into an ordered sequence the model works through top to bottom; later phases explicitly gate on earlier ones (e.g. refactor-js Phase 6 will not touch code until the user approves the plan from Phase 3–5).
- **File-based handoff between skills.** `clean-review-js` writes a timestamped report to `.claude-clean-review/<timestamp>.md` (with a YAML metadata header: `reviewed_at`, `scope`, `files_reviewed`); `refactor-js` reads only the most recent file in that directory (or an explicit filename argument) and never scans source independently. `tdd` relies on this same handoff when it chains the two together after each green test. When adding a skill that consumes another skill's output, follow this same "read the latest file in a known directory, or an explicit argument" pattern.
- **Cross-skill references use relative links**, e.g. `debug-gha` links to `../debug-mantra/SKILL.md` and `../post-mortem/SKILL.md`, and `tdd` links to `../clean-review-js/SKILL.md` and `../refactor-js/SKILL.md`. Note: `debug-gha` currently also documents a specific downstream project's GCP/Cloud Run deployment (service name, region, secrets) under a "This project's workflow" section — treat that section as an example to adapt, not a generic template, when reusing the skill elsewhere.
- **Confirm-before-acting gates.** `tdd` stops and asks the user before every phase transition (write test, run test, write implementation, run review, apply refactor, advance to next criterion) rather than running the whole loop autonomously — a stricter pattern than the other skills, used because the workflow is meant to keep the user in the loop at each red/green/refactor boundary.
- **Model pin for reasoning-heavy skills.** `clean-review-js` and `refactor-js` both specify `claude-opus-4-7` under a `## Model` heading, reserved for skills that need deep reasoning (subtle design issues, DDD boundary decisions).
- **Junior-dev-readable output.** Both review/refactor skills require every finding to explain what/why/how (or why/what-improves/what-breaks) in plain language, on the assumption the reader has ~6 months of experience.

## Adding a new skill

1. Create `skills/<category>/<skill-name>/SKILL.md` with frontmatter matching the conventions above.
2. Write an explicit, keyword-dense `description` — this is the only thing used to decide auto-triggering, so include literal phrases you expect users to type.
3. Scope `allowed-tools` as tightly as the skill needs (see existing skills for the `Bash(<command> *)` pattern of allowing specific subcommands rather than all of `Bash`).
4. Run `./scripts/link-skills.sh` to make it available locally.
