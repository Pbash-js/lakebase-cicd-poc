-- STATELESS: 05_triggers layer. Trigger function first (CREATE OR REPLACE), trigger guarded (no OR REPLACE).
CREATE OR REPLACE FUNCTION trg_orders_audit_fn()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE NOTICE 'order % changed by %', NEW.order_id, current_user;
    RETURN NEW;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_orders_audit') THEN
    CREATE TRIGGER trg_orders_audit
    AFTER UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION trg_orders_audit_fn();
  END IF;
END $$;
