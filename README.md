# Practical 02 Report: PostgreSQL Performance Analysis and Optimization

## 1. Objective

The goal of this assignment was to analyze PostgreSQL performance under load, find slow queries, locking problems, missing indexes, and apply optimizations.

The database `student_perf_lab` contained:

| Table                |    Rows |
| -------------------- | ------: |
| customers            |  20,000 |
| products             |   2,000 |
| orders               | 120,000 |
| order_items          | 360,267 |
| customer_events_wide | 200,000 |

## 2. Tools Used

I used:

* `pg_stat_statements`
* `EXPLAIN ANALYZE`
* `pg_stat_activity`
* `pg_blocking_pids()`
* lock wait monitoring

These tools helped identify slow queries, execution plans, blocked sessions, and lock waits.

## 3. Problems Found

### Slow aggregation

The query on `customer_events_wide` was slow because it scanned a large part of the table.

Before optimization:

```text
Seq Scan on customer_events_wide
Rows Removed by Filter: 101727
Execution Time: 101.062 ms
```

### Expensive joins

The join between `order_items` and `products` used a parallel sequential scan and hash join.

Before optimization:

```text
Parallel Seq Scan on order_items
Hash Join
Execution Time: 99.542 ms
```

The join between `customers`, `orders`, and `customer_events_wide` also scanned large tables.

Before optimization:

```text
Parallel Seq Scan on customer_events_wide
Seq Scan on customers
Execution Time: 76.225 ms
```

### Substring search

The query:

```sql
SELECT *
FROM customers
WHERE email LIKE '%gmail%';
```

was inefficient because a normal B-tree index does not work well with a leading `%`.

### Locking and deadlocks

Using `pg_stat_activity` and `pg_blocking_pids()`, I found sessions waiting on locks:

```text
transactionid
tuple
relation
```

The load generator also showed long waits and deadlocks:

```text
orders_writer: 8.688s
orders_writer: 11.058s
conflicting_customer_update: 10.837s
DEADLOCK detected and rolled back: 40P01
```

## 4. Optimizations Applied

I created indexes for filtered and joined columns:

```sql
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
```

The trigram GIN indexes were added for substring searches with `LIKE '%...%'`.

## 5. Before and After Results

| Query                       |     Before |     After |
| --------------------------- | ---------: | --------: |
| `events_aggregation`        | 101.062 ms | 87.627 ms |
| `items_products_join`       |  99.542 ms | 83.023 ms |
| `cartesian_pressure`        |  76.225 ms | 52.116 ms |
| `email LIKE '%gmail%'`      |   Seq Scan |  0.068 ms |
| `orders_by_city_and_status` |   Seq Scan | 12.191 ms |

The best result was for email search:

```text
Bitmap Index Scan on idx_customers_email_trgm
Execution Time: 0.068 ms
```

## 6. Wide Table Issue

The table `customer_events_wide` is too wide because it stores event data together with many optional attributes. Frequent updates of `attr_01`, `attr_02`, `attr_03`, and `attr_04` are inefficient.

A better solution is to split it into:

```text
customer_events
customer_event_attributes
```

This would reduce row width and make updates cheaper.

## 7. Concurrency Solution

Deadlocks happened because transactions locked the same customer rows in different order.

A better approach is to always lock rows in the same order:

```sql
BEGIN;

SELECT customer_id
FROM customers
WHERE customer_id IN (1, 2)
ORDER BY customer_id
FOR UPDATE;

COMMIT;
```

This reduces deadlocks. Transactions should also be shorter, and unnecessary table-level locks should be avoided.

## 8. Conclusion

I identified slow queries, missing indexes, wide table problems, lock waits, and deadlocks. After adding indexes and running `ANALYZE`, several queries became faster. The strongest improvement was the email substring search, which used a trigram GIN index and executed in `0.068 ms`.

The main concurrency improvement is to keep transactions short and lock rows in a consistent order.
