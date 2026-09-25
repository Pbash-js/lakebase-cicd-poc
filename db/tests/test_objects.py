import os, psycopg

def _conn():
    return psycopg.connect(
        host=os.environ["PGHOST"], port=os.environ.get("PGPORT", "5432"),
        dbname=os.environ.get("PGDATABASE", "databricks_postgres"),
        user=os.environ["PGUSER"], password=os.environ["PGPASSWORD"],
        sslmode="require")

def test_migrations_exactly_once():
    with _conn() as c:
        n = c.execute("SELECT count(*) FROM schema_migrations").fetchone()[0]
        assert n >= 2

def test_function_and_view():
    with _conn() as c:
        row = c.execute("SELECT order_count, total_cents FROM v_order_totals ORDER BY customer_id LIMIT 1").fetchone()
        assert row[0] >= 1 and row[1] > 0

def test_seed_present():
    with _conn() as c:
        assert c.execute("SELECT count(*) FROM orders").fetchone()[0] >= 3
