-- STATEFUL, run-once. Sample shipments table.
CREATE TABLE shipments (
    shipment_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id     BIGINT NOT NULL REFERENCES orders(order_id),
    carrier      TEXT NOT NULL DEFAULT 'blue-dart',
    status       TEXT NOT NULL DEFAULT 'pending',
    shipped_at   TIMESTAMPTZ
);
