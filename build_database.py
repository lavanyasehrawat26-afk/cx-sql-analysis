"""
Builds a SQLite database of SYNTHETIC customer-support data for the SQL analysis.
The data is randomly generated (seeded, so it is reproducible). It is not real company data.

Run:  python build_database.py
Creates: cx_support.db with tables customers, agents, interactions
"""
import random
import sqlite3
from datetime import datetime, timedelta

random.seed(42)

REGIONS = ["North", "South", "East", "West"]
CHANNELS = ["Voice", "Email", "Chat", "Social"]
CATEGORIES = ["Billing", "Technical", "Delivery", "Account", "Product Info"]
PLANS = ["Basic", "Standard", "Premium"]

conn = sqlite3.connect("cx_support.db")
cur = conn.cursor()
cur.executescript("""
DROP TABLE IF EXISTS interactions;
DROP TABLE IF EXISTS agents;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    region      TEXT NOT NULL,
    plan        TEXT NOT NULL,
    signup_date TEXT NOT NULL
);
CREATE TABLE agents (
    agent_id    INTEGER PRIMARY KEY,
    agent_name  TEXT NOT NULL,
    team        TEXT NOT NULL,
    hire_date   TEXT NOT NULL
);
CREATE TABLE interactions (
    interaction_id   INTEGER PRIMARY KEY,
    customer_id      INTEGER NOT NULL REFERENCES customers(customer_id),
    agent_id         INTEGER NOT NULL REFERENCES agents(agent_id),
    channel          TEXT NOT NULL,
    category         TEXT NOT NULL,
    created_at       TEXT NOT NULL,
    handle_minutes   REAL NOT NULL,
    resolved_first_contact INTEGER NOT NULL,   -- 1 = yes, 0 = no
    csat             INTEGER                   -- 1-5, NULL if customer did not respond
);
""")

# customers
customers = []
for cid in range(1, 801):
    signup = datetime(2023, 1, 1) + timedelta(days=random.randint(0, 900))
    customers.append((cid, random.choice(REGIONS),
                      random.choices(PLANS, weights=[50, 35, 15])[0],
                      signup.strftime("%Y-%m-%d")))
cur.executemany("INSERT INTO customers VALUES (?,?,?,?)", customers)

# agents (skill level shifts handle time and CSAT so there is something to find)
teams = ["Alpha", "Beta", "Gamma"]
agents, skill = [], {}
for aid in range(1, 31):
    hire = datetime(2022, 1, 1) + timedelta(days=random.randint(0, 1000))
    agents.append((aid, f"Agent {aid:02d}", random.choice(teams), hire.strftime("%Y-%m-%d")))
    skill[aid] = random.uniform(-1, 1)
cur.executemany("INSERT INTO agents VALUES (?,?,?,?)", agents)

# interactions: Jan-Dec 2025
base_minutes = {"Voice": 11, "Email": 7, "Chat": 9, "Social": 6}
cat_difficulty = {"Billing": 0, "Technical": 4, "Delivery": 1, "Account": 0.5, "Product Info": -2}
rows = []
start = datetime(2025, 1, 1)
for iid in range(1, 12001):
    day = start + timedelta(days=random.randint(0, 364), hours=random.randint(8, 21),
                            minutes=random.randint(0, 59))
    # volume grows slightly later in the year
    if random.random() < 0.15:
        day = day.replace(day=min(day.day, 28), month=random.choice([10, 11, 12]))
    cust = random.randint(1, 800)
    agent = random.randint(1, 30)
    ch = random.choices(CHANNELS, weights=[35, 25, 30, 10])[0]
    cat = random.choices(CATEGORIES, weights=[25, 30, 20, 15, 10])[0]
    handle = max(2, random.gauss(base_minutes[ch] + cat_difficulty[cat] - 1.5 * skill[agent], 2.5))
    p_fcr = 0.78 + 0.08 * skill[agent] - (0.15 if cat == "Technical" else 0)
    fcr = 1 if random.random() < min(max(p_fcr, 0.2), 0.97) else 0
    csat = None
    if random.random() < 0.55:
        score = 3.8 + 0.4 * skill[agent] + (0.6 if fcr else -0.9) - (0.2 if handle > 14 else 0)
        csat = int(min(5, max(1, round(random.gauss(score, 0.9)))))
    rows.append((iid, cust, agent, ch, cat, day.strftime("%Y-%m-%d %H:%M"),
                 round(handle, 1), fcr, csat))
cur.executemany("INSERT INTO interactions VALUES (?,?,?,?,?,?,?,?,?)", rows)

conn.commit()
for t in ("customers", "agents", "interactions"):
    print(t, cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0], "rows")
conn.close()
