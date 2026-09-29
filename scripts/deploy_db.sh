#!/usr/bin/env bash
# Lakebase deploy: mint OAuth credential -> migrations -> objects -> rbac -> tests.
# TARGET_BRANCH: env var wins; else prompted (interactive); else production (CI).
# Auth: local `databricks auth login` profile, or DATABRICKS_HOST + DATABRICKS_TOKEN in CI.
set -euo pipefail

PROJECT="${LAKEBASE_PROJECT:?set LAKEBASE_PROJECT (the Lakebase project id, e.g. from databricks.yml)}"
DATABRICKS_PG_USER="${DATABRICKS_PG_USER:?set DATABRICKS_PG_USER (your Lakebase Postgres role, e.g. your email)}"

if [ -z "${TARGET_BRANCH:-}" ]; then
  if [ -t 0 ]; then
    read -r -p "Target branch [production]: " _TB || _TB=""
    TARGET_BRANCH="${_TB:-production}"
  else
    TARGET_BRANCH="production"   # ponytail: non-interactive = CI; CI sets TARGET_BRANCH explicitly anyway
  fi
else
  TARGET_BRANCH_SET=1            # came from env (CI) — skip the interactive confirm
fi
if ! [[ "$TARGET_BRANCH" =~ ^[a-z][a-z0-9-]{0,62}$ ]]; then
  echo "Invalid branch id '$TARGET_BRANCH': 1-63 chars, lowercase start, lowercase/numbers/hyphens" >&2; exit 1
fi
if [ "$TARGET_BRANCH" != "production" ] && [ -t 0 ] && [ -z "${1:-}" ] && [ -z "${TARGET_BRANCH_SET:-}" ]; then
  printf "Deploy to non-production branch '%s' — type the branch name to confirm: " "$TARGET_BRANCH"
  read -r CONFIRM || CONFIRM=""
  [ "$CONFIRM" = "$TARGET_BRANCH" ] || { echo "aborted"; exit 1; }
fi

# preflight: fail fast with actionable messages, before touching anything
PREFLIGHT_FAIL=0
if ! databricks current-user me -o json >/dev/null 2>&1; then
  echo "✗ Databricks CLI not authenticated — run: databricks auth login"
  PREFLIGHT_FAIL=1
fi
[ "$PREFLIGHT_FAIL" = 0 ] || exit 1
echo "✓ preflight ok (authed via CLI; project: $PROJECT)"

trap 'echo "❌ deploy failed (line $LINENO). If auth was the problem: databricks auth login. If the token expired: re-run." >&2' ERR

ENDPOINT="projects/${PROJECT}/branches/${TARGET_BRANCH}/endpoints/primary"
echo "▶ target: $TARGET_BRANCH  (project: $PROJECT)"
HOST="$(databricks postgres get-endpoint "$ENDPOINT" --output json | python -c "import sys,json;print(json.load(sys.stdin)['status']['hosts']['host'])")"
TOKEN="$(databricks postgres generate-database-credential "$ENDPOINT" --output json | python -c "import sys,json;print(json.load(sys.stdin)['token'])")"

cd "$(dirname "$0")/.."

echo "▶ 1/3 migrations (exactly-once, drift-checked)"
python scripts/apply_migrations.py \
  --host "${HOST}" --port 5432 --dbname databricks_postgres \
  --user "${DATABRICKS_PG_USER}" --password "${TOKEN}" \
  --sslmode require --migrations-dir db/migrations

echo "▶ 2/3 objects (idempotent replay)"
python scripts/apply_objects.py \
  --host "${HOST}" --port 5432 --dbname databricks_postgres \
  --user "${DATABRICKS_PG_USER}" --password "${TOKEN}" \
  --sslmode require --objects-root db/objects

echo "▶ 3/3 rbac (idempotent replay)"
if [ -f scripts/apply_rbac.py ]; then
  python scripts/apply_rbac.py \
    --host "${HOST}" --port 5432 --dbname databricks_postgres \
    --user "${DATABRICKS_PG_USER}" --password "${TOKEN}" \
    --sslmode require --rbac-dir db/rbac
else
  echo "  no scripts/apply_rbac.py — skipped"
fi

if [ "${SKIP_TESTS:-}" = 1 ]; then
  echo "▶ SKIP_TESTS=1 — tests skipped"
elif [ -d db/tests ]; then
  echo "▶ tests"
  PGHOST="${HOST}" PGUSER="${DATABRICKS_PG_USER}" PGPASSWORD="${TOKEN}" \
    python -m pytest db/tests -q
else
  echo "▶ no db/tests directory — skipped"
fi

echo "✅ deployed to ${TARGET_BRANCH}"
