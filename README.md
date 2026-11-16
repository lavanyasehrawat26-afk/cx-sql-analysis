# Customer Support Analytics: SQL Project

A SQL analysis of customer-support interactions, written to practise business-intelligence reporting: volume trends, service quality, agent performance and customer satisfaction.

> **Data note:** the dataset is **synthetic** (randomly generated with a fixed seed by `build_database.py`). It is not real company data, and the patterns below describe this dataset only. The project demonstrates SQL technique, not real-world business conclusions.

## Dataset
SQLite database `cx_support.db` with 3 tables:

| Table | Rows | Description |
|---|---|---|
| `customers` | 800 | region, plan, signup date |
| `agents` | 30 | name, team, hire date |
| `interactions` | 12,000 | channel, issue category, date, handle time, first-contact resolution, CSAT (1-5, nullable) for 2025 |

## SQL concepts used
Aggregations (`COUNT`, `AVG`, `SUM`), `GROUP BY` / `HAVING`, `JOIN`, subqueries, CTEs (`WITH`), window functions (`LAG`, `RANK`, running `SUM() OVER`), `CASE` bucketing, `NULL` handling, date functions (`strftime`).

## Questions answered (see `queries.sql`, outputs in `results.md`)
1. Monthly volume and handle time
2. Month-over-month change (`LAG`)
3. Channel performance: volume, handle time, FCR, CSAT
4. Issue categories with the lowest first-contact resolution
5. CSAT by region and plan
6. Survey response rate by channel
7. Agent ranking within team (`RANK ... PARTITION BY`)
8. Handle-time buckets vs. CSAT and FCR
9. Customers with unusually high repeat contacts (subquery)
10. Running total and cumulative share of annual volume

## Key findings (on this synthetic data)
- **Technical issues resolve worst on first contact:** 63.3% FCR vs 76.7-79.1% for other categories, with the longest handle time (12.9 min).
- **Longer calls go with lower satisfaction:** average CSAT falls from 4.04 (under 5 min) to 3.58 (15+ min), and FCR falls from 79.8% to 67.2%.
- **Voice is the slowest channel** (12.2 min average) with no FCR advantage over chat or email.
- **Agent performance varies widely within teams:** the top and bottom agents in one team differ by 0.45-0.88 CSAT points, which would be the starting point for coaching.
- **Volume jumps 81.5% in October** (823 to 1,494) and stays high through December. This is a property of how the synthetic data was generated; in real data it would prompt checking for a campaign, outage or seasonality.

## How to run
```bash
python build_database.py          # regenerates cx_support.db
sqlite3 cx_support.db < queries.sql
```

## Possible extensions
- Build a Power BI or Tableau dashboard on these tables
- Add an SLA-breach analysis and a cohort view of repeat contacts
- Test whether CSAT differences between agents are statistically significant
