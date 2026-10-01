# Lakebase CI/CD POC — GitHub Actions + Cookbook Runner

POC implementation of the *Databricks Lakebase CI/CD Architecture Playbook v6*
(Cookbook-native migrations, no Flyway). Targets Databricks Free Edition.

## Repo layout
- `db/migrations/` — stateful, run-once plain SQL (`NNN_description.sql`), applied exactly-once by `scripts/apply_migrations.py` (Cookbook `migrations_runner.py`), tracked in `schema_migrations` with SHA-256 checksums. Editing an applied file = DRIFT, pipeline fails.
- `db/objects/` — stateless one-file-per-object SQL, re-applied idempotently (CREATE OR REPLACE) in layer order 01_types -> 02_functions -> 03_procedures -> 04_views -> 05_triggers.
- `db/tests/` — pytest suite run against the PR branch.
- `scripts/` — runner + deploy entrypoint (mints a 60-min OAuth DB credential per invocation).
- `.github/workflows/` — pr-validation.yml (ephemeral TTL branch per PR), cd-promotion.yml (replay to production on merge), cleanup-orphans.yml (weekly GC).
- `.github/CODEOWNERS` — second-pair-of-eyes: infra paths always request review.

## What each script and workflow does

**scripts/ (run in this order by deploy_db.sh)**

| File | What it does |
| --- | --- |
| migrations_runner.py | The Cookbook runner, verbatim. Scans `db/migrations/*.sql` in filename order, creates/uses the `schema_migrations` ledger (SHA-256 per file), skips applied files, fails on DRIFT (content changed after apply), rolls back per-file on error. |
| apply_migrations.py | Thin wrapper: opens the psycopg connection (OAuth token, sslmode=require) and calls the runner's `apply_pending()`. Exit code 0 = clean, 2 = drift. |
| apply_objects.py | Stage 2. Replays every file in `db/objects/` in layer order (01→05), one transaction per file. Files must converge (CREATE OR REPLACE / guarded) — running twice changes nothing. |
| apply_rbac.py | Stage 3. Replays `db/rbac/*.sql` idempotently (guarded roles + GRANTs). Auto-skipped here — the POC has no db/rbac/. |
| deploy_db.sh | The one entrypoint (local AND CI). Preflight (auth/config, actionable ✗), branch selection (TARGET_BRANCH in CI, interactive prompt with production default locally, non-prod needs typed confirm), mints a fresh 60-min OAuth credential, runs stages 1→2→3, then pytest automatically. `SKIP_TESTS=1` to skip. |
| new_sandbox.sh | Creates your personal dev branch off production (7-day TTL) and waits for its endpoint to go ACTIVE. One command, day one. |

**.github/workflows/**

| File | Trigger | What it does |
| --- | --- | --- |
| pr-validation.yml | any PR touching db/**, scripts/, databricks.yml, workflows | 1) integrity gate — infra files need the `infra-approved` label; 2) installs pinned CLI (1.17.0) + deps; 3) creates or reuses `pr-<n>` (24h TTL, idempotent on PR update); 4) waits for endpoint ACTIVE; 5) `deploy_db.sh` with TARGET_BRANCH=pr-<n> — rehearses exactly the merge, runs the tests. Exit code = the check. |
| cd-promotion.yml | merge to main | Serialized by concurrency group (`cancel-in-progress: false`). Bundle-deploy adopts the production branch/endpoint, then `deploy_db.sh` (TARGET_BRANCH=production): pending migrations exactly-once, objects replayed, tests. Second merge skips already-applied files. |
| cleanup-orphans.yml | weekly cron (Sat 03:00 UTC), manual | Safety net for expired-TTL PR branches: lists branches via the REST API (CLI has no list-branches), deletes any `pr-*` leftovers. Never touches production. |

## Local loop
```
databricks auth login --profile free-edition
export DATABRICKS_PG_USER=you@org.com
./scripts/deploy_db.sh            # prompts for target branch (default production); runs tests automatically
./scripts/new_sandbox.sh dev-<you>   # optional: personal sandbox branch, 7-day TTL
```

## GitHub secrets required (Settings -> Secrets and variables -> Actions)
| Secret | Example |
| --- | --- |
| DATABRICKS_HOST | https://dbc-xxxxxxxx.cloud.databricks.com |
| DATABRICKS_TOKEN | PAT (POC) or SP OAuth secret |
| LAKEBASE_PROJECT | core-app-db |
| DATABRICKS_PG_USER | your Lakebase Postgres role (user email or SP client id) |
