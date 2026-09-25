-- STATELESS: 01_types layer. Plain Postgres enum (no CREATE OR REPLACE support — guarded DO block).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') THEN
    CREATE TYPE order_status AS ENUM ('new', 'shipped', 'cancelled');
  END IF;
END $$;
