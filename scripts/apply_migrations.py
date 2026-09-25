"""Wrapper around the Cookbook migrations_runner: builds the psycopg
connection (sslmode=require — Lakebase rejects non-SSL), applies pending
migrations, prints results. Exit codes: 0 ok, 1 SQL failure, 2 drift."""
import argparse, sys
from pathlib import Path

import psycopg

from migrations_runner import apply_pending


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--port", default="5432")
    ap.add_argument("--dbname", default="databricks_postgres")
    ap.add_argument("--user", required=True)
    ap.add_argument("--password", required=True)
    ap.add_argument("--sslmode", default="require")
    ap.add_argument("--migrations-dir", default="db/migrations")
    args = ap.parse_args()

    with psycopg.connect(
        host=args.host, port=args.port, dbname=args.dbname,
        user=args.user, password=args.password, sslmode=args.sslmode,
    ) as conn:
        results = apply_pending(conn, Path(args.migrations_dir))
        drift = False
        for r in results:
            print(f"  {r.filename:<40} {'APPLIED' if r.applied else 'SKIPPED'} {r.note}")
            drift = drift or bool(r.note)
        if drift:
            print("DRIFT detected — fix is a new migration, never an edit to history.", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
