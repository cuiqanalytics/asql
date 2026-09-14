-- segment_scorecard.sql — the Few-style scorecard decorations on `table`/`kpi`, the other
-- small chart-level knobs that shipped alongside them (`-- lights:`, `-- delta-field:`,
-- `-- y-zero:`, `-- show-points:`, `-- filter-exclusive:`), and the two slider controls:
-- `-- slider:` (discrete) and `-- slider-range:` (min/max).
--
-- Reads the shared dataset in examples/data/ — regenerate it with
--   ./asql query examples/northwind.sql

-- @report
-- title: Northwind Cloud — Segment Scorecard
-- subtitle: Net revenue retention health by customer segment
-- author: Analytics
-- brand: Northwind Cloud
-- date-range: Sep 2024 – Aug 2026
-- refreshed-at: Aug 27, 2026 08:00
-- dataset-version: synthetic-v1
-- max-width: 1200px
-- toc: true
-- filter: segment
-- filter-exclusive: segment
-- slider: region
-- slider-range: deal_size

-- @setup
CREATE OR REPLACE VIEW segment_month AS FROM 'examples/data/segment_month.csv';
CREATE OR REPLACE VIEW region_plan   AS FROM 'examples/data/region_plan.csv';
CREATE OR REPLACE VIEW accounts      AS FROM 'examples/data/accounts.csv';

-- @section: headline
-- label: Headline
-- layout: kpi-grid

-- @chart: kpi
-- title: Ending MRR
-- format: dollar
-- delta-field: change

SELECT
    (SELECT SUM(mrr) FROM segment_month WHERE i = 23) AS value,
    (SELECT SUM(mrr) FROM segment_month WHERE i = 23)
        - (SELECT SUM(mrr) FROM segment_month WHERE i = 11) AS change;

-- @chart: kpi
-- title: Blended net revenue retention across all three segments
-- format: pct
-- delta-field: change
-- delta-label: pts vs 12 mo ago

SELECT
    ROUND(SUM(mrr * nrr) / SUM(mrr)) / 100 AS value,
    ROUND(SUM(mrr * nrr) / SUM(mrr)) / 100
        - (SELECT ROUND(SUM(mrr * nrr) / SUM(mrr)) / 100 FROM segment_month WHERE i = 11) AS change
FROM segment_month WHERE i = 23;

-- @chart: kpi
-- title: Active logos

SELECT SUM(logos) AS value FROM segment_month WHERE i = 23;

-- @markdown
-- title: Reading the scorecard below

-- Each row's **value** is the segment's latest net revenue retention. The colored dot comes
-- from `-- lights: 100, 115` — no `status` column needed: NRR under 100% (net churn) is red,
-- 100–115% is amber, 115%+ is green. The bar-and-tick is a **bullet-in-cell** against a
-- 100%-retention target, and the trailing badge is the **delta** column (▲/▼ vs. 24 months
-- ago). The **spark** column stays a visible sparkline of the full 24-month trend.

-- @chart: table
-- title: Segment health
-- lights: 100, 115

WITH trend AS (
    SELECT segment, list(nrr ORDER BY month) AS nrr_series
    FROM segment_month
    GROUP BY segment
)
SELECT
    segment AS dimension,
    nrr_series[len(nrr_series)] AS value,
    100 AS target,
    round(nrr_series[len(nrr_series)] - nrr_series[1], 1) AS delta,
    nrr_series::VARCHAR AS spark
FROM trend
ORDER BY value DESC;

-- @chart: trend
-- title: Net revenue retention by segment
-- y-label: NRR %

SELECT month AS date, segment AS series, nrr AS value
FROM segment_month
ORDER BY 1, 2;

-- @chart: trend
-- title: Blended NRR by quarter
-- y-label: NRR %
-- y-zero: false
-- show-points: false

SELECT DATE_TRUNC('quarter', month)::DATE AS date,
    ROUND(SUM(mrr * nrr) / SUM(mrr), 1) AS value
FROM segment_month
GROUP BY 1
ORDER BY 1;

-- @section: explore
-- label: Explore accounts
-- layout: two-col

-- @markdown
-- title: Sliders

-- The **Region** slider above steps through one region at a time (drag or use arrow keys)
-- instead of picking from a dropdown — good for a handful of ordered values. The **Deal
-- size** range slider narrows the boxplot below to accounts within that revenue band; drag
-- either thumb. Both write to the URL hash the same way `-- filter:` does.

-- @chart: comparison
-- title: MRR vs. plan by region
-- format: dollar

SELECT region AS dimension, region AS series, actual_mrr AS value
FROM region_plan
ORDER BY actual_mrr DESC;

-- @chart: boxplot
-- title: Deal size distribution by segment
-- format: dollar

SELECT segment AS dimension, deal_size AS value FROM accounts;
