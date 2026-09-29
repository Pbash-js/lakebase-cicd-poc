-- STATEFUL, run-once. Add fulfillment note column + backfill via view usage.
ALTER TABLE orders ADD COLUMN note TEXT NOT NULL DEFAULT '';
