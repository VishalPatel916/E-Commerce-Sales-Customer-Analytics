-- Olist e-commerce schema (SQLite dialect; types/keys map 1:1 to PostgreSQL).
-- Timestamps are stored as ISO-8601 text ('YYYY-MM-DD HH:MM:SS').
-- PostgreSQL port: use TIMESTAMP, NUMERIC(10,2), and replace strftime()/julianday()
-- in analysis_queries.sql with DATE_TRUNC()/EXTRACT(EPOCH FROM ...) (see sql/README.md).

PRAGMA foreign_keys = OFF;

DROP TABLE IF EXISTS order_items; DROP TABLE IF EXISTS payments; DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS orders; DROP TABLE IF EXISTS customers; DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS sellers; DROP TABLE IF EXISTS category_translation; DROP TABLE IF EXISTS geolocation;

CREATE TABLE customers (
    customer_id              TEXT PRIMARY KEY,
    customer_unique_id       TEXT NOT NULL,
    customer_zip_code_prefix TEXT,
    customer_city            TEXT,
    customer_state           TEXT
);

CREATE TABLE sellers (
    seller_id              TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city            TEXT,
    seller_state           TEXT
);

CREATE TABLE category_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

CREATE TABLE products (
    product_id                 TEXT PRIMARY KEY,
    product_category_name      TEXT,
    product_name_lenght        INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty         INTEGER,
    product_weight_g           REAL,
    product_length_cm          REAL,
    product_height_cm          REAL,
    product_width_cm           REAL
);

CREATE TABLE orders (
    order_id                       TEXT PRIMARY KEY,
    customer_id                    TEXT NOT NULL REFERENCES customers(customer_id),
    order_status                   TEXT,
    order_purchase_timestamp       TEXT,
    order_approved_at              TEXT,
    order_delivered_carrier_date   TEXT,
    order_delivered_customer_date  TEXT,
    order_estimated_delivery_date  TEXT
);

CREATE TABLE order_items (
    order_id            TEXT NOT NULL REFERENCES orders(order_id),
    order_item_id       INTEGER NOT NULL,
    product_id          TEXT REFERENCES products(product_id),
    seller_id           TEXT REFERENCES sellers(seller_id),
    shipping_limit_date TEXT,
    price               REAL,
    freight_value       REAL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE payments (
    order_id             TEXT NOT NULL REFERENCES orders(order_id),
    payment_sequential   INTEGER NOT NULL,
    payment_type         TEXT,
    payment_installments INTEGER,
    payment_value        REAL,
    PRIMARY KEY (order_id, payment_sequential)
);

-- review_id is NOT unique in the source data and an order can have >1 review,
-- so there is deliberately no primary key here (see notebooks/02_data_cleaning).
CREATE TABLE reviews (
    review_id               TEXT,
    order_id                TEXT REFERENCES orders(order_id),
    review_score            INTEGER,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TEXT,
    review_answer_timestamp TEXT
);

CREATE TABLE geolocation (
    geolocation_zip_code_prefix TEXT,
    geolocation_lat             REAL,
    geolocation_lng             REAL,
    geolocation_city            TEXT,
    geolocation_state           TEXT
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status   ON orders(order_status);
CREATE INDEX idx_items_product   ON order_items(product_id);
CREATE INDEX idx_items_seller    ON order_items(seller_id);
CREATE INDEX idx_reviews_order   ON reviews(order_id);
