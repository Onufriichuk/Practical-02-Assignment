optimization.sql

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_customers_email
ON customers(email);

CREATE INDEX IF NOT EXISTS idx_customers_email_trgm
ON customers USING gin (email gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_customers_status
ON customers(status);

CREATE INDEX IF NOT EXISTS idx_orders_status_delivery_city
ON orders(status, delivery_city);

CREATE INDEX IF NOT EXISTS idx_orders_delivery_city_trgm
ON orders USING gin (delivery_city gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_customer_events_event_time
ON customer_events_wide(event_time);

CREATE INDEX IF NOT EXISTS idx_customer_events_customer_time_type
ON customer_events_wide(customer_id, event_time, event_type);

CREATE INDEX IF NOT EXISTS idx_orders_customer_status
ON orders(customer_id, status);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
ON order_items(product_id);

ANALYZE customers;
ANALYZE orders;
ANALYZE order_items;
ANALYZE "customer_events_wide";
