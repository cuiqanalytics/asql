-- northwind.sql — regenerates examples/data/*.csv, the shared synthetic dataset every
-- example in this directory reads from.
--
-- Run from the repo root:   ./asql query examples/northwind.sql
-- (or `make examples`, which does this first). CSV output is byte-deterministic, so the
-- committed files only change when this generator does.
--
-- "Northwind Cloud" is a fictional B2B SaaS company: 24 months of history
-- (Sep 2024 – Aug 2026) across three segments. Every value is a smooth deterministic
-- function of the row index — no random() — so the charts tell the same story every run.

-- Monthly performance by customer segment.
CREATE OR REPLACE TEMP TABLE segment_month AS
SELECT
    (DATE '2024-09-01' + INTERVAL (i) MONTH)::DATE AS month,
    i,
    seg AS segment,
    round(CASE seg
        WHEN 'Enterprise' THEN 600000 + 19000 * i + 15000 * sin(i * 0.6)
        WHEN 'Mid-Market' THEN 400000 + 9500 * i + 9000 * sin(i * 0.5)
        ELSE 345000 + 1600 * i + 7000 * sin(i * 0.8)
    END, 2) AS mrr,
    round(CASE seg
        WHEN 'Enterprise' THEN 112 + 12 * (i / 23.0) + 1.5 * sin(i * 0.55)
        WHEN 'Mid-Market' THEN 103 + 4 * (i / 23.0) + 1.1 * sin(i * 0.7)
        ELSE 100 - 11 * (i / 23.0) - 1.6 * sin(i * 0.6) + 1.2 * sin(i * 1.7)
    END, 1) AS nrr,
    round(CASE seg
        WHEN 'Enterprise' THEN 1.1 - 0.2 * (i / 23.0) + 0.15 * sin(i * 0.9)
        WHEN 'Mid-Market' THEN 1.6 - 0.1 * (i / 23.0) + 0.12 * sin(i * 1.3)
        ELSE 1.6 + 3.3 * (i / 23.0) + 0.3 * sin(i * 0.9) + 0.2 * sin(i * 2.1)
    END, 2) AS gross_churn_rate,
    CASE seg
        WHEN 'Enterprise' THEN 90 + 3 * i + round(6 * sin(i * 0.7))
        WHEN 'Mid-Market' THEN 140 + 5 * i + round(10 * sin(i * 0.5))
        ELSE 700 + 10 * i + round(35 * sin(i * 0.8)) - (i % 3) * 40
    END::INTEGER AS logos
FROM generate_series(0, 23) AS t(i)
CROSS JOIN (VALUES ('Enterprise'), ('Mid-Market'), ('SMB')) AS s(seg)
ORDER BY month, segment;

-- Company-wide MRR bridge. ending_mrr equals SUM(segment_month.mrr) exactly; the four
-- bridge components are synthesised to sum to each month's net change (churn is the
-- balancing residual), so the waterfall reconciles with every segment total.
CREATE OR REPLACE TEMP TABLE mrr_monthly AS
WITH totals AS (
    SELECT i, month, round(SUM(mrr), 2) AS total_mrr FROM segment_month GROUP BY 1, 2
),
d AS (
    SELECT i, month, total_mrr,
        total_mrr - LAG(total_mrr, 1, total_mrr - 40000) OVER (ORDER BY i) AS net_change
    FROM totals
),
parts AS (
    SELECT i, month, total_mrr, net_change,
        round(38000 + 3200 * sin(i * 0.8) + 2100 * sin(i * 1.7) + 0.55 * GREATEST(net_change, 0), 2) AS new_mrr,
        round(14000 + 2400 * sin(i * 0.5) + 0.30 * GREATEST(net_change, 0), 2) AS expansion_mrr,
        round(-(3200 + 900 * (sin(i * 1.1) + 1)), 2) AS contraction_mrr
    FROM d
)
SELECT
    month, i, new_mrr, expansion_mrr, contraction_mrr,
    round(net_change - new_mrr - expansion_mrr - contraction_mrr, 2) AS churned_mrr,
    round(total_mrr - net_change, 2) AS starting_mrr,
    total_mrr AS ending_mrr
FROM parts
ORDER BY i;

-- Net revenue retention, blended and per segment (MRR-weighted).
CREATE OR REPLACE TEMP TABLE nrr_monthly AS
SELECT
    i, month,
    ROUND(SUM(mrr * nrr) / SUM(mrr), 1) AS blended_nrr,
    ROUND(SUM(mrr * nrr) FILTER (WHERE segment = 'Enterprise')
        / NULLIF(SUM(mrr) FILTER (WHERE segment = 'Enterprise'), 0), 1) AS enterprise_nrr,
    ROUND(SUM(mrr * nrr) FILTER (WHERE segment = 'Mid-Market')
        / NULLIF(SUM(mrr) FILTER (WHERE segment = 'Mid-Market'), 0), 1) AS midmarket_nrr,
    ROUND(SUM(mrr * nrr) FILTER (WHERE segment = 'SMB')
        / NULLIF(SUM(mrr) FILTER (WHERE segment = 'SMB'), 0), 1) AS smb_nrr
FROM segment_month
GROUP BY 1, 2
ORDER BY i;

-- One row per customer account: unit economics.
CREATE OR REPLACE TEMP TABLE accounts AS
SELECT
    i AS account_id,
    (['SMB', 'Mid-Market', 'Enterprise'])[1 + i % 3] AS segment,
    CASE i % 3
        WHEN 0 THEN 900 + (i * 53) % 1600
        WHEN 1 THEN 4200 + (i * 91) % 5000
        ELSE 18000 + (i * 173) % 22000
    END AS cac,
    CASE i % 3
        WHEN 0 THEN 82 + (i * 17) % 18
        WHEN 1 THEN 100 + (i * 13) % 16
        ELSE 112 + (i * 29) % 20
    END AS nrr,
    CASE i % 3
        WHEN 0 THEN 300 + (i * 41) % 900
        WHEN 1 THEN 1500 + (i * 67) % 4000
        ELSE 9000 + (i * 137) % 30000
    END AS deal_size
FROM generate_series(0, 59) AS t(i)
ORDER BY account_id;

-- Actual vs. plan MRR by sales region. actual_mrr splits the current company total
-- (SUM of segment_month.mrr at the latest month) across four regions.
CREATE OR REPLACE TEMP TABLE region_plan AS
WITH total AS (SELECT SUM(mrr) AS t FROM segment_month WHERE i = 23)
SELECT region,
    round((SELECT t FROM total) * share, 2) AS actual_mrr,
    round((SELECT t FROM total) * plan_share, 2) AS plan_mrr
FROM (VALUES
    ('North America', 0.46, 0.44),
    ('EMEA', 0.29, 0.32),
    ('APAC', 0.16, 0.15),
    ('LATAM', 0.09, 0.09)
) AS t(region, share, plan_share);

-- Blended unit economics by segment.
CREATE OR REPLACE TEMP TABLE segment_economics AS
SELECT * FROM (VALUES
    ('SMB', 1400, 14.0, 91),
    ('Mid-Market', 6200, 9.0, 106),
    ('Enterprise', 28000, 16.0, 123)
) AS t(segment, cac, payback_months, nrr);

-- New-business funnel, last full quarter.
CREATE OR REPLACE TEMP TABLE pipeline AS
SELECT * FROM (VALUES
    ('Lead', 12000), ('MQL', 4800), ('SQL', 1900),
    ('Opportunity', 780), ('Closed Won', 240)
) AS t(stage, value);

-- SMB logo retention by signup cohort and months since signup.
CREATE OR REPLACE TEMP TABLE smb_cohorts AS
SELECT
    strftime(DATE '2025-09-01' + INTERVAL (c) MONTH, '%Y-%m') AS cohort,
    m AS months_since_signup,
    GREATEST(28, 100
        - CASE
            WHEN m = 0 THEN 0
            WHEN m = 1 THEN 12
            WHEN m = 2 THEN 26
            WHEN m = 3 THEN 38
            WHEN m = 4 THEN 44
            WHEN m = 5 THEN 48
            ELSE 51
        END
        - c * 1.5)::INTEGER AS retention_pct
FROM generate_series(0, 5) AS a(c)
CROSS JOIN generate_series(0, 6) AS b(m)
ORDER BY cohort, months_since_signup;

-- 12-month forward MRR projection, three scenarios (demos per-series colour / dash).
CREATE OR REPLACE TEMP TABLE mrr_projection AS
SELECT
    (DATE '2026-08-01' + INTERVAL (k) MONTH)::DATE AS month,
    s.scenario,
    round(1529000 * pow(1 + s.rate, k), 2) AS mrr
FROM generate_series(0, 12) AS t(k)
CROSS JOIN (VALUES
    ('baseline', 0.021),
    ('aggressive', 0.034),
    ('downside', 0.009)
) AS s(scenario, rate)
ORDER BY month, scenario;

COPY segment_month     TO 'examples/data/segment_month.csv'     (HEADER);
COPY mrr_monthly       TO 'examples/data/mrr_monthly.csv'       (HEADER);
COPY nrr_monthly       TO 'examples/data/nrr_monthly.csv'       (HEADER);
COPY accounts          TO 'examples/data/accounts.csv'          (HEADER);
COPY region_plan       TO 'examples/data/region_plan.csv'       (HEADER);
COPY segment_economics TO 'examples/data/segment_economics.csv' (HEADER);
COPY pipeline          TO 'examples/data/pipeline.csv'          (HEADER);
COPY smb_cohorts       TO 'examples/data/smb_cohorts.csv'       (HEADER);
COPY mrr_projection    TO 'examples/data/mrr_projection.csv'    (HEADER);

SELECT 'northwind: wrote 9 CSVs to examples/data/' AS status;
