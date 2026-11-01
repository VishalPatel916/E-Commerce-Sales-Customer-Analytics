-- =====================================================================
-- Olist analysis queries (SQLite dialect). Run all with: python src/run_sql.py
-- Each block starts with "-- name: <id>" and "-- question: <what it answers>".
-- Metric definitions used throughout:
--   item_revenue  = SUM(order_items.price)                (excludes freight)
--   gmv           = SUM(price + freight_value)
--   payment_value = SUM(payments.payment_value)           (what customers paid)
--   "completed" order = order_status = 'delivered'
-- Grain warning: order_items and payments are both many-per-order. They are
-- ALWAYS aggregated to one row per order in a CTE before being joined together.
-- =====================================================================

-- name: q01_order_status_mix
-- question: What proportion of orders are delivered, canceled or otherwise not completed?
SELECT order_status,
       COUNT(*)                                              AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)    AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- name: q02_monthly_item_revenue
-- question: How does delivered-order item revenue change month by month? (with MoM growth via LAG)
WITH monthly AS (
    SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS month,
           COUNT(DISTINCT o.order_id)                    AS orders,
           SUM(oi.price)                                 AS item_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
)
SELECT month, orders, ROUND(item_revenue, 2) AS item_revenue,
       ROUND(100.0 * (item_revenue - LAG(item_revenue) OVER (ORDER BY month))
             / LAG(item_revenue) OVER (ORDER BY month), 1) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- name: q03_top_categories
-- question: Which product categories contribute the most revenue and item volume?
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(*)                                         AS items_sold,
       ROUND(SUM(oi.price), 2)                          AS item_revenue,
       ROUND(100.0 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 2) AS revenue_share_pct,
       ROUND(AVG(oi.price), 2)                          AS avg_item_price
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id AND o.order_status = 'delivered'
JOIN products p ON p.product_id = oi.product_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
GROUP BY category
ORDER BY item_revenue DESC
LIMIT 15;

-- name: q04_category_pareto
-- question: How concentrated is revenue? Cumulative share of revenue by category rank (window functions).
WITH cat AS (
    SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           SUM(oi.price) AS rev
    FROM order_items oi
    JOIN orders o   ON o.order_id = oi.order_id AND o.order_status = 'delivered'
    JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    GROUP BY category
), ranked AS (
    SELECT category, rev, RANK() OVER (ORDER BY rev DESC) AS rev_rank,
           SUM(rev) OVER (ORDER BY rev DESC ROWS UNBOUNDED PRECEDING) AS cum_rev,
           SUM(rev) OVER () AS total_rev
    FROM cat
)
SELECT rev_rank, category, ROUND(rev, 2) AS item_revenue,
       ROUND(100.0 * cum_rev / total_rev, 1) AS cumulative_share_pct
FROM ranked
WHERE rev_rank <= 20
ORDER BY rev_rank;

-- name: q05_order_value_summary
-- question: What is the average order value (AOV) and how skewed is it? (order grain via CTE)
WITH order_value AS (
    SELECT o.order_id, SUM(oi.price) AS item_value, SUM(oi.price + oi.freight_value) AS total_value
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
), ranked AS (
    SELECT item_value, total_value,
           ROW_NUMBER() OVER (ORDER BY item_value) AS rn,
           COUNT(*) OVER ()                         AS n
    FROM order_value
)
SELECT COUNT(*)                         AS orders,
       ROUND(AVG(item_value), 2)        AS aov_items_mean,
       ROUND(MAX(CASE WHEN rn = CAST(n * 0.5  AS INT) THEN item_value END), 2) AS aov_items_median,
       ROUND(MAX(CASE WHEN rn = CAST(n * 0.9  AS INT) THEN item_value END), 2) AS p90,
       ROUND(MAX(CASE WHEN rn = CAST(n * 0.99 AS INT) THEN item_value END), 2) AS p99,
       ROUND(MAX(item_value), 2)        AS max_value,
       ROUND(AVG(total_value), 2)       AS aov_incl_freight_mean
FROM ranked;

-- name: q06_state_performance
-- question: Which states contribute the most orders and revenue? (3-table join + RANK)
SELECT c.customer_state AS state,
       COUNT(DISTINCT o.order_id)  AS orders,
       ROUND(SUM(oi.price), 2)     AS item_revenue,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS revenue_per_order,
       RANK() OVER (ORDER BY SUM(oi.price) DESC) AS revenue_rank
FROM orders o
JOIN customers c    ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY item_revenue DESC;

-- name: q07_top_cities
-- question: Which cities have the most delivered orders? (HAVING filters out tiny cities)
SELECT c.customer_city AS city, c.customer_state AS state,
       COUNT(DISTINCT o.order_id) AS orders
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_city, c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 500
ORDER BY orders DESC;

-- name: q08_repeat_customer_share
-- question: What share of unique customers place more than one delivered order? (CTE + CASE)
WITH per_customer AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS n_orders
    FROM orders o JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT CASE WHEN n_orders = 1 THEN '1 order'
            WHEN n_orders = 2 THEN '2 orders'
            ELSE '3+ orders' END AS segment,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_customers
FROM per_customer
GROUP BY segment
ORDER BY MIN(n_orders);

-- name: q09_top_repeat_customers
-- question: Who are the most frequent buyers and how much did they spend? (subquery + ROW_NUMBER)
SELECT customer_unique_id, delivered_orders, ROUND(total_item_spend, 2) AS total_item_spend
FROM (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS delivered_orders,
           SUM(oi.price)              AS total_item_spend,
           ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT o.order_id) DESC, SUM(oi.price) DESC) AS rn
    FROM orders o
    JOIN customers c    ON c.customer_id = o.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) t
WHERE rn <= 10;

-- name: q10_payment_types
-- question: Which payment types are used most and what are their typical payment values?
SELECT payment_type,
       COUNT(*)                         AS payment_rows,
       COUNT(DISTINCT order_id)         AS orders,
       ROUND(AVG(payment_value), 2)     AS avg_payment_value,
       ROUND(AVG(payment_installments), 2) AS avg_installments,
       ROUND(100.0 * COUNT(DISTINCT order_id) /
             (SELECT COUNT(DISTINCT order_id) FROM payments), 2) AS pct_of_orders
FROM payments
GROUP BY payment_type
ORDER BY orders DESC;

-- name: q11_delivery_time_by_month
-- question: How long does delivery take, and how often are orders late? (date arithmetic + CASE)
SELECT strftime('%Y-%m', order_purchase_timestamp) AS month,
       COUNT(*) AS delivered_orders,
       ROUND(AVG(julianday(order_delivered_customer_date) - julianday(order_purchase_timestamp)), 2) AS avg_delivery_days,
       ROUND(100.0 * AVG(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1.0 ELSE 0 END), 2) AS pct_late
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01' AND order_purchase_timestamp < '2018-09-01'
GROUP BY 1
ORDER BY 1;

-- name: q12_review_score_by_delay
-- question: How do review scores vary with delivery delay? (CTE; one review score per order via AVG, because 547 orders have >1 review)
WITH order_review AS (
    SELECT order_id, AVG(review_score) AS review_score FROM reviews GROUP BY order_id
), bucketed AS (
    SELECT o.order_id, r.review_score,
           julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) AS days_vs_estimate
    FROM orders o JOIN order_review r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
)
SELECT CASE WHEN days_vs_estimate <= -7 THEN 'a) 7+ days early'
            WHEN days_vs_estimate <= 0  THEN 'b) on time (0-7 days early)'
            WHEN days_vs_estimate <= 3  THEN 'c) 0-3 days late'
            WHEN days_vs_estimate <= 7  THEN 'd) 3-7 days late'
            ELSE 'e) 7+ days late' END AS delivery_bucket,
       COUNT(*) AS orders,
       ROUND(AVG(review_score), 3) AS avg_review_score,
       ROUND(100.0 * AVG(CASE WHEN review_score <= 2 THEN 1.0 ELSE 0 END), 1) AS pct_1_2_star
FROM bucketed
GROUP BY delivery_bucket
ORDER BY delivery_bucket;

-- name: q13_seller_leaderboard
-- question: Top sellers by revenue with their review quality (CTEs aggregating at the right grain first)
WITH seller_rev AS (
    SELECT oi.seller_id, COUNT(DISTINCT oi.order_id) AS orders, SUM(oi.price) AS item_revenue
    FROM order_items oi JOIN orders o ON o.order_id = oi.order_id AND o.order_status = 'delivered'
    GROUP BY oi.seller_id
), order_review AS (
    SELECT order_id, AVG(review_score) AS score FROM reviews GROUP BY order_id
), seller_score AS (
    SELECT oi.seller_id, AVG(r.score) AS avg_score
    FROM (SELECT DISTINCT order_id, seller_id FROM order_items) oi
    JOIN order_review r ON r.order_id = oi.order_id
    GROUP BY oi.seller_id
)
SELECT s.seller_id, s.seller_state, sr.orders, ROUND(sr.item_revenue, 2) AS item_revenue,
       ROUND(ss.avg_score, 2) AS avg_review_score,
       DENSE_RANK() OVER (ORDER BY sr.item_revenue DESC) AS revenue_rank
FROM seller_rev sr
JOIN sellers s       ON s.seller_id  = sr.seller_id
LEFT JOIN seller_score ss ON ss.seller_id = sr.seller_id
ORDER BY sr.item_revenue DESC
LIMIT 10;

-- name: q14_top_category_per_state
-- question: What is the #1 revenue category in each state? (window function inside CTE, filtered outside)
WITH sc AS (
    SELECT c.customer_state AS state,
           COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           SUM(oi.price) AS rev
    FROM orders o
    JOIN customers c    ON c.customer_id = o.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products p     ON p.product_id  = oi.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY state, category
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY state ORDER BY rev DESC) AS rn FROM sc
)
SELECT state, category, ROUND(rev, 2) AS item_revenue FROM ranked WHERE rn = 1 ORDER BY item_revenue DESC;

-- name: q15_customer_second_purchase_gap
-- question: How many days pass between a customer's first and second order? (LAG over customer history)
WITH ordered AS (
    SELECT c.customer_unique_id, o.order_purchase_timestamp AS ts,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY o.order_purchase_timestamp) AS order_seq,
           LAG(o.order_purchase_timestamp) OVER (PARTITION BY c.customer_unique_id ORDER BY o.order_purchase_timestamp) AS prev_ts
    FROM orders o JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
)
SELECT COUNT(*) AS repeat_customers,
       ROUND(AVG(julianday(ts) - julianday(prev_ts)), 1) AS avg_days_to_second_order,
       ROUND(MIN(julianday(ts) - julianday(prev_ts)), 1) AS min_days,
       ROUND(MAX(julianday(ts) - julianday(prev_ts)), 1) AS max_days
FROM ordered
WHERE order_seq = 2;

-- name: q16_freight_share_by_category
-- question: In which categories does freight eat the biggest share of what the customer pays?
SELECT COALESCE(t.product_category_name_english, 'unknown') AS category,
       COUNT(*) AS items,
       ROUND(SUM(oi.freight_value), 0) AS freight_total,
       ROUND(100.0 * SUM(oi.freight_value) / SUM(oi.price + oi.freight_value), 1) AS freight_pct_of_gmv
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id AND o.order_status = 'delivered'
JOIN products p ON p.product_id = oi.product_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
GROUP BY category
HAVING COUNT(*) >= 500
ORDER BY freight_pct_of_gmv DESC
LIMIT 10;

-- name: q17_payment_reconciliation
-- question: Do payments reconcile to items + freight? (both sides pre-aggregated to order grain to avoid row fan-out)
WITH items AS (
    SELECT order_id, SUM(price + freight_value) AS expected FROM order_items GROUP BY order_id
), pays AS (
    SELECT order_id, SUM(payment_value) AS paid FROM payments GROUP BY order_id
)
SELECT COUNT(*) AS orders_compared,
       SUM(CASE WHEN ABS(i.expected - p.paid) <= 1.00 THEN 1 ELSE 0 END) AS within_1_brl,
       SUM(CASE WHEN ABS(i.expected - p.paid) >  1.00 THEN 1 ELSE 0 END) AS differs_over_1_brl,
       ROUND(SUM(i.expected), 2) AS total_expected,
       ROUND(SUM(p.paid), 2)     AS total_paid
FROM items i JOIN pays p ON p.order_id = i.order_id;

-- name: q18_weekday_hour_demand
-- question: When do customers buy? Orders by weekday and time-of-day block.
SELECT CASE strftime('%w', order_purchase_timestamp)
         WHEN '0' THEN '7-Sun' WHEN '1' THEN '1-Mon' WHEN '2' THEN '2-Tue' WHEN '3' THEN '3-Wed'
         WHEN '4' THEN '4-Thu' WHEN '5' THEN '5-Fri' ELSE '6-Sat' END AS weekday,
       CASE WHEN CAST(strftime('%H', order_purchase_timestamp) AS INT) BETWEEN 0  AND 5  THEN 'night'
            WHEN CAST(strftime('%H', order_purchase_timestamp) AS INT) BETWEEN 6  AND 11 THEN 'morning'
            WHEN CAST(strftime('%H', order_purchase_timestamp) AS INT) BETWEEN 12 AND 17 THEN 'afternoon'
            ELSE 'evening' END AS day_block,
       COUNT(*) AS orders
FROM orders
GROUP BY weekday, day_block
ORDER BY weekday, day_block;

-- name: q19_categories_with_low_reviews
-- question: Which large categories have the lowest average review score? (subquery in HAVING)
WITH order_review AS (SELECT order_id, AVG(review_score) AS score FROM reviews GROUP BY order_id),
cat_orders AS (
    SELECT DISTINCT oi.order_id, COALESCE(t.product_category_name_english, 'unknown') AS category
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
)
SELECT co.category, COUNT(*) AS reviewed_orders, ROUND(AVG(r.score), 3) AS avg_score
FROM cat_orders co JOIN order_review r ON r.order_id = co.order_id
GROUP BY co.category
HAVING COUNT(*) >= (SELECT COUNT(*) * 0.005 FROM order_review)
ORDER BY avg_score ASC
LIMIT 10;

-- name: q20_cohort_retention
-- question: Of customers acquired in each quarter, what % ever placed a 2nd delivered order? (CTE cohorts)
WITH firsts AS (
    SELECT c.customer_unique_id,
           MIN(o.order_purchase_timestamp) AS first_ts,
           COUNT(DISTINCT o.order_id)      AS n_orders
    FROM orders o JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT strftime('%Y', first_ts) || '-Q' || ((CAST(strftime('%m', first_ts) AS INT) + 2) / 3) AS cohort_quarter,
       COUNT(*) AS customers,
       ROUND(100.0 * AVG(CASE WHEN n_orders > 1 THEN 1.0 ELSE 0 END), 2) AS pct_repeat
FROM firsts
WHERE first_ts >= '2017-01-01' AND first_ts < '2018-07-01'
GROUP BY cohort_quarter
ORDER BY cohort_quarter;
