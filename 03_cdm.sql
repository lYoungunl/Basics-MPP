DROP TABLE IF EXISTS cdm.dm_sales_performance CASCADE;

CREATE TABLE cdm.dm_sales_performance (
    report_dt DATE,
    campaign_id INT,
    campaign_name VARCHAR(100),
    channel_id INT,
    channel_name VARCHAR(50),
    orders_count INT,
    customers_count INT,
    order_amount NUMERIC(15, 2),
    avg_order_amount NUMERIC(15, 2),
    new_customers INT,
    campaign_budget NUMERIC(10, 2),
    spend NUMERIC(15, 2),
    revenue NUMERIC(15, 2),
    roi NUMERIC(10, 2)
) DISTRIBUTED BY (campaign_id);

INSERT INTO cdm.dm_sales_performance
WITH 
order_stats AS (
    SELECT 
        o.order_dt AS report_dt,
        o.campaign_id,
        COUNT(DISTINCT o.order_id) AS orders_count,
        COUNT(DISTINCT o.customer_id) AS customers_count,
        SUM(o.order_amount) AS order_amount,
        AVG(o.order_amount) AS avg_order_amount
    FROM dds.fact_orders o
    WHERE o.order_status = 'completed'
    GROUP BY o.order_dt, o.campaign_id
),
new_cust AS (
    SELECT 
        MIN(o.order_dt) AS first_order_dt,
        o.campaign_id,
        o.customer_id
    FROM dds.fact_orders o
    WHERE o.order_status = 'completed'
    GROUP BY o.campaign_id, o.customer_id
),
new_cust_agg AS (
    SELECT 
        first_order_dt AS report_dt,
        campaign_id,
        COUNT(DISTINCT customer_id) AS new_customers
    FROM new_cust
    GROUP BY first_order_dt, campaign_id
)
SELECT 
    s.report_dt,
    s.campaign_id,
    c.campaign_name,
    c.channel_id,
    ch.channel_name,
    s.orders_count,
    s.customers_count,
    s.order_amount,
    s.avg_order_amount,
    COALESCE(n.new_customers, 0) AS new_customers,
    c.budget AS campaign_budget,
    (c.budget / 30)::numeric(15,2) AS spend,
    s.order_amount AS revenue,
    CASE 
        WHEN (c.budget / 30) > 0 THEN ((s.order_amount - (c.budget / 30)) / (c.budget / 30))::numeric(10,2)
        ELSE 0
    END AS roi
FROM order_stats s
JOIN dds.dim_campaigns c ON s.campaign_id = c.campaign_id
JOIN dds.dim_channels ch ON c.channel_id = ch.channel_id
LEFT JOIN new_cust_agg n ON s.report_dt = n.report_dt AND s.campaign_id = n.campaign_id
ORDER BY s.report_dt, s.campaign_id;

ANALYZE cdm.dm_sales_performance;