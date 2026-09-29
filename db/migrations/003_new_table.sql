CREATE TABLE transactions (
    txn_id    BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_id BIGINT NOT NULL REFERENCES customers(customer_id),
    order_id    BIGINT NOT NULL REFERENCES orders(order_id),
    amount_cents BIGINT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata    JSONB NOT NULL DEFAULT '{}',
    PRIMARY KEY (txn_id)
);
