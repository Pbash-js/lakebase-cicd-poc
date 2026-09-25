"""Apply stateless code objects idempotently, in layer order.
01_types -> 02_functions -> 03_procedures -> 04_views -> 05_triggers.
Every file must be safe to replay (CREATE OR REPLACE / guarded DO blocks)."""
import argparse, sys
from pathlib import Path

import psycopg

LAYER_ORDER = ["01_types", "02_functions", "03_procedures", "04_views", "05_triggers"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--port", default="5432")
    ap.add_argument("--dbname", default="databricks_postgres")
    ap.add_argument("--user", required=True)
    ap.add_argument("--password", required=True)
    ap.add_argument("--sslmode", default="require")
    ap.add_argument("--objects-root", default="db/objects")
    args = ap.parse_args()

    root = Path(args.objects_root)
    files = []
    for layer in LAYER_ORDER:
        d = root / layer
        if d.is_dir():
            files += sorted(d.glob("*.sql"))

    with psycopg.connect(
        host=args.host, port=args.port, dbname=args.dbname,
        user=args.user, password=args.password, sslmode=args.sslmode,
    ) as conn:
        for path in files:
            sql = path.read_text(encoding="utf-8")
            label = str(path.relative_to(root))
            try:
                with conn.transaction():
                    conn.execute(sql)
                print(f"  {label:<50} APPLIED (idempotent replay)")
            except Exception as e:
                print(f"  {label}: FAILED — {e}", file=sys.stderr)
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
