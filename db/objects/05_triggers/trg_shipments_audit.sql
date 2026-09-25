-- STATELESS: 05_triggers layer. Audit trigger on shipments.
CREATE OR REPLACE FUNCTION trg_shipments_audit_fn()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE NOTICE 'shipment % for order % -> %', NEW.shipment_id, NEW.order_id, NEW.status;
    RETURN NEW;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_shipments_audit') THEN
    CREATE TRIGGER trg_shipments_audit
    AFTER INSERT OR UPDATE ON shipments
    FOR EACH ROW EXECUTE FUNCTION trg_shipments_audit_fn();
  END IF;
END $$;
