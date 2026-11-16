-- Customer Support Analytics: 10 SQL queries (SQLite)
-- Data: synthetic, 2025 (see README). Tables: customers, agents, interactions.

-- Q1: Monthly interaction volume and average handle time
SELECT strftime('%Y-%m', created_at) AS month,
       COUNT(*)                      AS interactions,
       ROUND(AVG(handle_minutes), 1) AS avg_handle_min
FROM interactions
GROUP BY month
ORDER BY month;

-- Q2: Month-over-month volume change (window function LAG)
WITH monthly AS (
    SELECT strftime('%Y-%m', created_at) AS month, COUNT(*) AS interactions
    FROM interactions
    GROUP BY month
)
SELECT month,
       interactions,
       LAG(interactions) OVER (ORDER BY month) AS prev_month,
       ROUND(100.0 * (interactions - LAG(interactions) OVER (ORDER BY month))
             / LAG(interactions) OVER (ORDER BY month), 1) AS mom_change_pct
FROM monthly
ORDER BY month;

-- Q3: Performance by channel: volume, handle time, first-contact resolution, CSAT
SELECT channel,
       COUNT(*)                               AS interactions,
       ROUND(AVG(handle_minutes), 1)          AS avg_handle_min,
       ROUND(100.0 * AVG(resolved_first_contact), 1) AS fcr_pct,
       ROUND(AVG(csat), 2)                    AS avg_csat
FROM interactions
GROUP BY channel
ORDER BY interactions DESC;

-- Q4: Which issue categories resolve worst on first contact? (HAVING filters small groups)
SELECT category,
       COUNT(*)                                      AS interactions,
       ROUND(100.0 * AVG(resolved_first_contact), 1) AS fcr_pct,
       ROUND(AVG(handle_minutes), 1)                 AS avg_handle_min
FROM interactions
GROUP BY category
HAVING COUNT(*) > 500
ORDER BY fcr_pct ASC;

-- Q5: CSAT by region and plan (JOIN to customers)
SELECT c.region,
       c.plan,
       COUNT(i.csat)          AS survey_responses,
       ROUND(AVG(i.csat), 2)  AS avg_csat
FROM interactions i
JOIN customers c ON c.customer_id = i.customer_id
WHERE i.csat IS NOT NULL
GROUP BY c.region, c.plan
ORDER BY c.region, avg_csat DESC;

-- Q6: Survey response rate by channel (NULL handling)
SELECT channel,
       COUNT(*)                                   AS interactions,
       COUNT(csat)                                AS responses,
       ROUND(100.0 * COUNT(csat) / COUNT(*), 1)   AS response_rate_pct
FROM interactions
GROUP BY channel
ORDER BY response_rate_pct DESC;

-- Q7: Agent ranking by CSAT within each team (RANK window function, minimum 20 responses)
WITH agent_stats AS (
    SELECT a.agent_id, a.agent_name, a.team,
           COUNT(i.csat)                  AS responses,
           ROUND(AVG(i.csat), 2)          AS avg_csat,
           ROUND(AVG(i.handle_minutes), 1) AS avg_handle_min
    FROM agents a
    JOIN interactions i ON i.agent_id = a.agent_id
    GROUP BY a.agent_id, a.agent_name, a.team
    HAVING COUNT(i.csat) >= 20
)
SELECT team, agent_name, responses, avg_csat, avg_handle_min,
       RANK() OVER (PARTITION BY team ORDER BY avg_csat DESC) AS rank_in_team
FROM agent_stats
ORDER BY team, rank_in_team;

-- Q8: Does a long handle time hurt satisfaction? (CASE bucketing)
SELECT CASE WHEN handle_minutes < 5  THEN '1) under 5 min'
            WHEN handle_minutes < 10 THEN '2) 5-10 min'
            WHEN handle_minutes < 15 THEN '3) 10-15 min'
            ELSE                          '4) 15+ min' END AS handle_bucket,
       COUNT(*)                                      AS interactions,
       ROUND(AVG(csat), 2)                           AS avg_csat,
       ROUND(100.0 * AVG(resolved_first_contact), 1) AS fcr_pct
FROM interactions
GROUP BY handle_bucket
ORDER BY handle_bucket;

-- Q9: Repeat contacts: customers with more than the average number of interactions (subquery)
SELECT c.customer_id, c.region, c.plan, COUNT(*) AS contacts
FROM interactions i
JOIN customers c ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.region, c.plan
HAVING COUNT(*) > (SELECT 1.0 * COUNT(*) / COUNT(DISTINCT customer_id) FROM interactions) * 1.5
ORDER BY contacts DESC
LIMIT 15;

-- Q10: Running total of interactions through the year, with share of annual volume (cumulative window)
WITH monthly AS (
    SELECT strftime('%Y-%m', created_at) AS month, COUNT(*) AS interactions
    FROM interactions
    GROUP BY month
)
SELECT month,
       interactions,
       SUM(interactions) OVER (ORDER BY month) AS running_total,
       ROUND(100.0 * SUM(interactions) OVER (ORDER BY month)
             / SUM(interactions) OVER (), 1)   AS cumulative_pct_of_year
FROM monthly
ORDER BY month;
