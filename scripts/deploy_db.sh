#!/usr/bin/env bash
# Mint a fresh OAuth DB credential (60-min TTL) and run the Cookbook runner.
# Auth: local profile via `databricks auth login`, or env DATABRICKS_HOST +
# DATABRICKS_TOKEN in CI. TARGET_BRANCH defaults to production.
set -euo pipefail

PROJECT="${LAKEBASE_PROJECT:-core-app-db}"
ENDPOINT="projects/${PROJECT}/branches/${TARGET_BRANCH:-production}/endpoints/primary"

HOST="$(databricks postgres get-endpoint "$ENDPOINT" --output json | jq -r .status.hosts.host)"
TOKEN="$(databricks postgres generate-database-credential "$ENDPOINT" --output json | jq -r .token)"

cd "$(dirname "$0")/.."
python scripts/apply_migrations.py \
  --host "${HOST}" --port 5432 --dbname databricks_postgres \
  --user "${DATABRICKS_PG_USER:?set DATABRICKS_PG_USER}" --password "${TOKEN}" \
  --sslmode require --migrations-dir db/migrations

python scripts/apply_objects.py \
  --host "${HOST}" --port 5432 --dbname databricks_postgres \
  --user "${DATABRICKS_PG_USER}" --password "${TOKEN}" \
  --sslmode require --objects-root db/objects
