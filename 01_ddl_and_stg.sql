-- 1. Создание схем
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dds;
CREATE SCHEMA IF NOT EXISTS cdm;

-- 2. Очистка таблиц
DROP TABLE IF EXISTS stg.order_items CASCADE;
DROP TABLE IF EXISTS stg.orders CASCADE;
DROP TABLE IF EXISTS stg.campaigns CASCADE;
DROP TABLE IF EXISTS stg.channels CASCADE;
DROP TABLE IF EXISTS stg.customers CASCADE;

-- 3. Создание таблиц STG
CREATE TABLE stg.customers (
    customer_id INT,
    customer_name VARCHAR(100),
    signup_dt DATE,
    region VARCHAR(50),
    customer_segment VARCHAR(50)
) DISTRIBUTED BY (customer_id);

CREATE TABLE stg.channels (
    channel_id INT,
    channel_name VARCHAR(50),
    channel_type VARCHAR(50)
) DISTRIBUTED BY (channel_id);

CREATE TABLE stg.campaigns (
    campaign_id INT,
    campaign_name VARCHAR(100),
    channel_id INT,
    start_dt DATE,
    end_dt DATE,
    budget NUMERIC(10, 2)
) DISTRIBUTED BY (campaign_id);

CREATE TABLE stg.orders (
    order_id INT,
    order_dt DATE,
    customer_id INT,
    campaign_id INT,
    order_amount NUMERIC(10, 2),
    order_status VARCHAR(20)
) DISTRIBUTED BY (order_id)
PARTITION BY RANGE (order_dt)
(START ('2023-01-01'::date) END ('2024-01-01'::date) EVERY ('1 month'::interval));

CREATE TABLE stg.order_items (
    order_item_id INT,
    order_id INT,
    product_id INT,
    product_name VARCHAR(100),
    quantity INT,
    price NUMERIC(10, 2)
) DISTRIBUTED BY (order_item_id);

-- 4. Генерация данных в STG
INSERT INTO stg.customers (customer_id, customer_name, signup_dt, region, customer_segment)
SELECT i, 'Customer_' || i, '2023-01-01'::date + (i % 300), (ARRAY['North', 'South', 'East', 'West'])[1 + (i % 4)], (ARRAY['Retail', 'VIP', 'New', 'Corporate'])[1 + (i % 4)]
FROM generate_series(1, 100) AS i;

INSERT INTO stg.channels (channel_id, channel_name, channel_type)
SELECT i, 'Channel_' || i, (ARRAY['Social', 'Search', 'Email', 'Display'])[i]
FROM generate_series(1, 4) AS i;

INSERT INTO stg.campaigns (campaign_id, campaign_name, channel_id, start_dt, end_dt, budget)
SELECT i, 'Campaign_' || i, 1 + (i % 4), '2023-01-01'::date + (i * 10), '2023-01-01'::date + (i * 10) + 30, (random() * 10000 + 1000)::numeric(10,2)
FROM generate_series(1, 10) AS i;

INSERT INTO stg.orders (order_id, order_dt, customer_id, campaign_id, order_amount, order_status)
SELECT i, '2023-01-01'::date + (random() * 300)::int, 1 + (random() * 99)::int, 1 + (random() * 9)::int, (random() * 5000 + 100)::numeric(10,2), (ARRAY['completed', 'cancelled', 'returned'])[1 + (random() * 2)::int]
FROM generate_series(1, 600) AS i;

INSERT INTO stg.order_items (order_item_id, order_id, product_id, product_name, quantity, price)
SELECT i, 1 + (random() * 599)::int, 1 + (random() * 50)::int, 'Product_' || (1 + (random() * 50)::int), 1 + (random() * 5)::int, (random() * 1000 + 50)::numeric(10,2)
FROM generate_series(1, 2000) AS i;