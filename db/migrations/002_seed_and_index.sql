-- STATEFUL, run-once. Seed data + index.
INSERT INTO customers (name) VALUES ('Acme Corp'), ('Globex'), ('Initech');

INSERT INTO orders (customer_id, status, total_cents)
SELECT customer_id, 'shipped', (customer_id * 1234) % 90000 + 500
FROM customers;

CREATE INDEX idx_orders_customer ON orders (customer_id);
