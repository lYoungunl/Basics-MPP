-- 1. Очистка и создание витрины
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

-- 2. Наполнение витрины
INSERT INTO cdm.dm_sales_performance
WITH 
-- 1. Генерируем календарь кампаний
campaign_calendar AS (
    SELECT 
        c.campaign_id,
        c.campaign_name,
        c.channel_id,
        ch.channel_name,
        c.budget,
        d::date AS report_dt,
        c.end_dt,
        c.start_dt,
        -- Округляем ежедневный расход сразу до 2 знаков
        ROUND((c.budget / (c.end_dt - c.start_dt + 1))::numeric, 2) AS daily_spend
    FROM dds.dim_campaigns c
    JOIN dds.dim_channels ch ON c.channel_id = ch.channel_id
    CROSS JOIN generate_series(c.start_dt, c.end_dt, '1 day'::interval) AS d
),
-- 2. Корректируем последний день
campaign_calendar_fixed AS (
    SELECT 
        campaign_id,
        campaign_name,
        channel_id,
        channel_name,
        budget,
        report_dt,
        CASE 
            WHEN report_dt = end_dt THEN 
                budget - (daily_spend * (end_dt - start_dt))
            ELSE daily_spend
        END::numeric(15,2) AS spend
    FROM campaign_calendar
),
-- 3. Агрегируем данные по заказам (только completed)
order_stats AS (
    SELECT 
        o.order_dt AS report_dt,
        o.campaign_id,
        COUNT(DISTINCT o.order_id) AS orders_count,
        COUNT(DISTINCT o.customer_id) AS customers_count,
        SUM(o.order_amount) AS revenue,
        AVG(o.order_amount) AS avg_order_amount
    FROM dds.fact_orders o
    WHERE o.order_status = 'completed'
    GROUP BY o.order_dt, o.campaign_id
),
-- 4. Считаем новых клиентов
new_cust AS (
    SELECT 
        customer_id,
        MIN(order_dt) AS first_order_dt
    FROM dds.fact_orders
    WHERE order_status = 'completed'
    GROUP BY customer_id
),
new_cust_agg AS (
    SELECT 
        f.campaign_id,
        f.order_dt AS report_dt,
        COUNT(DISTINCT n.customer_id) AS new_customers
    FROM dds.fact_orders f
    JOIN new_cust n ON f.customer_id = n.customer_id AND f.order_dt = n.first_order_dt
    WHERE f.order_status = 'completed'
    GROUP BY f.campaign_id, f.order_dt
)
-- 5. Собираем всё вместе
SELECT 
    cal.report_dt,
    cal.campaign_id,
    cal.campaign_name,
    cal.channel_id,
    cal.channel_name,
    COALESCE(s.orders_count, 0) AS orders_count,
    COALESCE(s.customers_count, 0) AS customers_count,
    COALESCE(s.revenue, 0) AS order_amount,
    COALESCE(s.avg_order_amount, 0) AS avg_order_amount,
    COALESCE(n.new_customers, 0) AS new_customers,
    cal.budget AS campaign_budget,
    cal.spend,
    COALESCE(s.revenue, 0) AS revenue,
    CASE 
        WHEN cal.spend > 0 THEN ((COALESCE(s.revenue, 0) - cal.spend) / cal.spend)::numeric(10,2)
        ELSE 0
    END AS roi
FROM campaign_calendar_fixed cal
LEFT JOIN order_stats s ON cal.report_dt = s.report_dt AND cal.campaign_id = s.campaign_id
LEFT JOIN new_cust_agg n ON cal.report_dt = n.report_dt AND cal.campaign_id = n.campaign_id
ORDER BY cal.report_dt, cal.campaign_id;

-- 3. Обновление статистики
ANALYZE cdm.dm_sales_performance;