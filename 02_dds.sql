-- 1. Очистка таблиц DDS
DROP TABLE IF EXISTS dds.dim_customers CASCADE;
DROP TABLE IF EXISTS dds.dim_channels CASCADE;
DROP TABLE IF EXISTS dds.dim_campaigns CASCADE;
DROP TABLE IF EXISTS dds.fact_orders CASCADE;
DROP TABLE IF EXISTS dds.fact_order_items CASCADE;

-- 2. Создание таблиц DDS

CREATE TABLE dds.dim_customers (
    customer_id INT,
    customer_name VARCHAR(100),
    signup_dt DATE,
    region VARCHAR(50),
    customer_segment VARCHAR(50),
    load_dt TIMESTAMP DEFAULT NOW(),
    load_src VARCHAR(50) DEFAULT 'stg.customers'
) DISTRIBUTED BY (customer_id);

CREATE TABLE dds.dim_channels (
    channel_id INT,
    channel_name VARCHAR(50),
    channel_type VARCHAR(50),
    load_dt TIMESTAMP DEFAULT NOW(),
    load_src VARCHAR(50) DEFAULT 'stg.channels'
) DISTRIBUTED BY (channel_id);

CREATE TABLE dds.dim_campaigns (
    campaign_id INT,
    campaign_name VARCHAR(100),
    channel_id INT,
    start_dt DATE,
    end_dt DATE,
    budget NUMERIC(10, 2),
    load_dt TIMESTAMP DEFAULT NOW(),
    load_src VARCHAR(50) DEFAULT 'stg.campaigns'
) DISTRIBUTED BY (campaign_id);

CREATE TABLE dds.fact_orders (
    order_id INT,
    order_dt DATE,
    customer_id INT,
    campaign_id INT,
    order_amount NUMERIC(10, 2),
    order_status VARCHAR(20),
    load_dt TIMESTAMP DEFAULT NOW(),
    load_src VARCHAR(50) DEFAULT 'stg.orders'
) DISTRIBUTED BY (order_id)
PARTITION BY RANGE (order_dt)
(START ('2023-01-01'::date) END ('2024-01-01'::date) EVERY ('1 month'::interval));

-- DISTRIBUTED BY (order_id) для корректного джойна
CREATE TABLE dds.fact_order_items (
    order_item_id INT,
    order_id INT,
    product_id INT,
    product_name VARCHAR(100),
    quantity INT,
    price NUMERIC(10, 2),
    load_dt TIMESTAMP DEFAULT NOW(),
    load_src VARCHAR(50) DEFAULT 'stg.order_items'
) DISTRIBUTED BY (order_id);

-- 3. Наполнение DDS
INSERT INTO dds.dim_customers (customer_id, customer_name, signup_dt, region, customer_segment)
SELECT DISTINCT customer_id, customer_name, signup_dt, region, customer_segment FROM stg.customers;

INSERT INTO dds.dim_channels (channel_id, channel_name, channel_type)
SELECT DISTINCT channel_id, channel_name, channel_type FROM stg.channels;

INSERT INTO dds.dim_campaigns (campaign_id, campaign_name, channel_id, start_dt, end_dt, budget)
SELECT DISTINCT campaign_id, campaign_name, channel_id, start_dt, end_dt, budget FROM stg.campaigns;

INSERT INTO dds.fact_orders (order_id, order_dt, customer_id, campaign_id, order_amount, order_status)
SELECT order_id, order_dt, customer_id, campaign_id, order_amount, order_status FROM stg.orders;

INSERT INTO dds.fact_order_items (order_item_id, order_id, product_id, product_name, quantity, price)
SELECT order_item_id, order_id, product_id, product_name, quantity, price FROM stg.order_items;

-- 4. Обновление статистики
ANALYZE dds.fact_orders;
ANALYZE dds.fact_order_items;