-- Отчет 1. Топ кампаний по ROI
SELECT 
    campaign_name,
    SUM(revenue) AS total_revenue,
    SUM(spend) AS total_spend,
    ROUND((SUM(revenue) - SUM(spend)) / NULLIF(SUM(spend), 0), 2) AS overall_roi
FROM cdm.dm_sales_performance
GROUP BY campaign_name
ORDER BY overall_roi DESC
LIMIT 5;

-- Отчет 2. Сравнение фактических затрат и бюджета
SELECT 
    campaign_name,
    MAX(campaign_budget) AS budget,
    SUM(spend) AS total_spend,
    (MAX(campaign_budget) - SUM(spend)) AS remaining_budget
FROM cdm.dm_sales_performance
GROUP BY campaign_name
ORDER BY remaining_budget ASC;

-- Отчет 3. Анализ новых клиентов в кампании
SELECT 
    campaign_name,
    SUM(new_customers) AS total_new_customers,
    SUM(customers_count) AS total_customers
FROM cdm.dm_sales_performance
GROUP BY campaign_name
ORDER BY total_new_customers DESC;

-- Отчет 4. Отчет по рекламным каналам
SELECT 
    channel_name,
    SUM(orders_count) AS total_orders,
    SUM(revenue) AS total_revenue,
    SUM(spend) AS total_spend,
    ROUND((SUM(revenue) - SUM(spend)) / NULLIF(SUM(spend), 0), 2) AS overall_roi
FROM cdm.dm_sales_performance
GROUP BY channel_name
ORDER BY total_revenue DESC;

-- ПРОВЕРКИ КАЧЕСТВА ДАННЫХ

-- 1. Проверка: бюджеты кампаний должны сходиться с расходами
SELECT 
    campaign_name,
    MAX(campaign_budget) AS budget,
    SUM(spend) AS calculated_spend,
    (MAX(campaign_budget) - SUM(spend)) AS diff
FROM cdm.dm_sales_performance
GROUP BY campaign_name
HAVING ABS(MAX(campaign_budget) - SUM(spend)) > 0.1; 

-- 2. Проверка: нет отрицательных метрик
SELECT COUNT(*) AS negative_metrics_count
FROM cdm.dm_sales_performance
WHERE revenue < 0 OR spend < 0 OR orders_count < 0 OR customers_count < 0;

-- 3. Проверка: новые клиенты не больше общего числа клиентов
SELECT COUNT(*) AS invalid_new_customers_count
FROM cdm.dm_sales_performance
WHERE new_customers > customers_count;

-- 4. Проверка сходимости выручки в CDM и DDS (заказы completed)
SELECT 
    (SELECT SUM(revenue) FROM cdm.dm_sales_performance) AS cdm_revenue,
    (SELECT SUM(order_amount) FROM dds.fact_orders WHERE order_status = 'completed') AS dds_revenue,
    (SELECT SUM(revenue) FROM cdm.dm_sales_performance) - (SELECT SUM(order_amount) FROM dds.fact_orders WHERE order_status = 'completed') AS diff;
-- Ожидаемый результат: diff = 0