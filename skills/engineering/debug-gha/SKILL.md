---
name: debug-gha
description: Debug a failing GitHub Actions pipeline by fetching logs directly via gh CLI, then applying the debug-mantra four-step discipline. Never asks the user to paste logs — fetches everything itself. Trigger on /debug-gha and proactively when the user says a workflow, pipeline, or CI job is broken or failing.
---

# Debug GHA

Debug a failing GitHub Actions pipeline autonomously — fetch all the raw material yourself, never ask the user to paste logs.

Apply the [`debug-mantra`](../debug-mantra/SKILL.md) four steps throughout.

## Recite this — verbatim, as the first thing in your first response

> **Mantra:**
> 1. **First is reproducibility.** Can the failure be reproduced reliably, or is it flaky?
> 2. **Know the fail path.** Find the first error line, not the last.
> 3. **Question your hypothesis.** What would disprove it?
> 4. **Every run is a breadcrumb.** Cross-reference all of them.

Then begin work.

---

## Step 0 — Gather context autonomously

Run these before asking the user anything. If `gh` is not authenticated, stop and say so.

```bash
# Confirm auth
gh auth status

# Identify the repo (if not already known)
gh repo view --json nameWithOwner -q .nameWithOwner

# List recent runs for every workflow to find failing ones
gh run list --limit=20 --json databaseId,workflowName,conclusion,headBranch,headSha,createdAt,url
```

From the output, pick the **most recent failed run** (conclusion: `failure`) on the target branch (default: `main`). If multiple workflows are failing, address them one at a time starting with the most recent.

---

## Step 1 — Reproduce reliably

**Is this failure consistent or flaky?**

```bash
# Pull the last 10 runs of the failing workflow
gh run list --workflow=<workflow-file>.yml --limit=10 \
  --json databaseId,conclusion,headSha,createdAt \
  | jq '.[] | {id: .databaseId, result: .conclusion, sha: .headSha, at: .createdAt}'
```

- **Fails on every recent push** → consistent. Proceed.
- **Passes ~50% of the time** → flaky. Note it in the ledger, look for timing/network/concurrency causes before assuming code.
- **Started failing after a specific commit** → diff that commit against the workflow file and `Dockerfile` first.

Re-trigger the failing job (not the full workflow) to confirm it re-fails before spending time on it:

```bash
gh run rerun <run-id> --failed
```

---

## Step 2 — Know the fail path

**Find the first error, not the last.** Fetch logs directly:

```bash
# See which jobs are in the run and their status
gh run view <run-id>

# Stream the full log for the failing job
gh run view <run-id> --log --job=<job-id>

# If you need the log as a file for grep/analysis
gh run download <run-id> --dir /tmp/gha-logs
```

**Triage order inside the log:**
1. Find the first step marked failed (❌).
2. Inside that step, find the **last non-zero exit** or thrown error — that is the actual failure.
3. Check the step immediately before for warnings that explain the state entering the failing step.
4. Ignore errors in steps that ran *after* the first failure — they are cascades.

**Common failure categories to check in order:**

| Category | First signal |
|---|---|
| GCP auth | `You do not currently have an active account` or `PERMISSION_DENIED` on gcloud |
| Artifact Registry push | `unauthorized` or `denied` after `docker push` |
| Docker build | `ERROR [stage N/M]` with non-zero exit; look at the `RUN` instruction line |
| Missing secret / empty build-arg | Build passes but runtime shows 401s or blank config — `NEXT_PUBLIC_*` vars are baked in at `next build` |
| Cloud Run deploy | `PERMISSION_DENIED` or `The user-provided container failed to start` |
| Next.js build OOM/TS error | TypeScript errors, missing env vars, or runner OOM in the build step |

Fetch the workflow file to check secret injection and build-arg wiring:

```bash
cat .github/workflows/deploy.yml
```

Check which secrets exist (values are redacted, but presence is visible):

```bash
gh secret list
```

---

## Step 3 — Falsify the hypothesis

Before acting, try to disprove the most obvious hypothesis.

**Phantom hypotheses and their disproofs:**

- *"A secret is wrong or missing"* → did this workflow ever succeed with the same secret? If yes, the secret value is fine — look at what changed in the workflow file. Confirm presence with `gh secret list`.
- *"The Docker build is broken"* → does it build locally with the same `--build-arg` values? If yes, the issue is how the workflow injects args, not the `Dockerfile`.
- *"GCP permissions changed"* → check if the SA key or project ID was rotated recently. Verify the SA has: `roles/run.admin`, `roles/artifactregistry.writer`, `roles/storage.admin`.
- *"Cloud Run is rejecting the image"* → pull the pushed image tag and run it locally with `docker run -e ... -p 3000:3000 <image>`. If it crashes locally, the issue is the app, not Cloud Run config.
- *"`NEXT_PUBLIC_*` vars are missing at runtime"* → a missing `--build-arg` does **not** fail `next build`; it silently bakes in an empty string. The build step passes, but the deployed app breaks. Always verify baked-in vars by inspecting the built bundle or Cloud Run logs.

Generate 3–5 ranked hypotheses. Rank by: (1) what changed most recently, (2) which step is first to actually fail.

---

## Step 4 — Every run is a breadcrumb

Keep a running ledger as you inspect runs. Each entry: run ID, what was different, pass/fail, what it rules in or out.

```bash
# Cross-reference run history with commits
gh run list --workflow=deploy.yml --limit=20 \
  --json databaseId,conclusion,headSha,createdAt \
  | jq '.[] | {id: .databaseId, result: .conclusion, sha: .headSha, at: .createdAt}'
```

Before committing to a hypothesis, walk the ledger: does it explain *every* run's outcome? If any prior run contradicts it, refine or discard.

---

## Deployment verification (post-fix)

After a fix is deployed, confirm the new revision is live and healthy:

```bash
# Confirm the new revision is serving traffic
gcloud run services describe miumi-frontend \
  --region=asia-southeast1 \
  --format='value(status.traffic)'

# Tail Cloud Run logs
gcloud logging read \
  'resource.type=cloud_run_revision AND resource.labels.service_name=miumi-frontend' \
  --limit=50 --format='value(textPayload)' --order=asc
```

---

## This project's workflow

Workflow: `.github/workflows/deploy.yml` — triggers on push to `main`. Builds a Docker image with `NEXT_PUBLIC_*` vars baked in at build time via `--build-arg`, pushes to Artifact Registry (`asia-southeast1-docker.pkg.dev`), deploys to Cloud Run service `miumi-frontend` in `asia-southeast1`.

Required secrets: `GCP_SA_KEY`, `GCP_PROJECT_ID`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_OMISE_PUBLIC_KEY`, `NEXT_PUBLIC_ENABLE_TRUEMONEY`.

---

## Operating rules

- **Never ask the user to paste logs** — fetch them with `gh run view --log` or `gh run download`.
- Recite the mantra block once per session, verbatim, in your first response. If the user says "skip the mantra" → skip the recital but still apply the four steps silently.
- Do not propose a fix before step 1 is satisfied (know whether the failure is consistent).
- Do not guess root cause from the step name — read the actual log text.
- Do not recommend rotating secrets until confirmed missing or incorrect — rotation has blast radius beyond this workflow.
- After landing a fix, offer to hand off to [`post-mortem`](../post-mortem/SKILL.md) for the engineering record.
