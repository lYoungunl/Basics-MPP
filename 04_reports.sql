-- Отчет 1. Топ кампаний по ROI
SELECT campaign_name, SUM(revenue) AS total_revenue, SUM(spend) AS total_spend, ROUND(SUM(revenue) / NULLIF(SUM(spend), 0), 2) AS overall_roi
FROM cdm.dm_sales_performance GROUP BY campaign_name ORDER BY overall_roi DESC LIMIT 5;

-- Отчет 2. Сравнение фактических затрат и бюджета
SELECT campaign_name, MAX(campaign_budget) AS budget, SUM(spend) AS total_spend, (MAX(campaign_budget) - SUM(spend)) AS remaining_budget
FROM cdm.dm_sales_performance GROUP BY campaign_name ORDER BY remaining_budget ASC;

-- Отчет 3. Анализ новых клиентов в кампании
SELECT campaign_name, SUM(new_customers) AS total_new_customers, SUM(customers_count) AS total_customers
FROM cdm.dm_sales_performance GROUP BY campaign_name ORDER BY total_new_customers DESC;

-- Отчет 4. Отчет по рекламным каналам
SELECT channel_name, SUM(orders_count) AS total_orders, SUM(revenue) AS total_revenue, SUM(spend) AS total_spend, ROUND(AVG(roi), 2) AS avg_roi
FROM cdm.dm_sales_performance GROUP BY channel_name ORDER BY total_revenue DESC;