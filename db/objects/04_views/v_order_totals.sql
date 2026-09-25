-- STATELESS: 04_views layer. CREATE OR REPLACE VIEW is idempotent.
CREATE OR REPLACE VIEW v_order_totals AS
SELECT c.customer_id,
       c.name,
       COUNT(o.order_id)             AS order_count,
       fn_total_for_customer(c.customer_id) AS total_cents
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.name;
