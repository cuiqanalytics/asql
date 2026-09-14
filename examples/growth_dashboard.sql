-- growth_dashboard.sql — Northwind Cloud's interactive monitoring dashboard, and the
-- companion to growth_review.sql (the same data and story as a written memo). Laid out
-- for at-a-glance monitoring: a hero headline, a KPI grid, claim/chart pairs, a
-- sidebar-main cohort view, and a tabbed appendix (its last tab is a Sankey - the one
-- chart here that's a raw Vega v5 spec, not Vega-Lite). The segment filter at the top
-- re-slices every Vega-Lite chart on the page in the browser.
--
-- Reads the shared dataset in examples/data/ — regenerate it with
--   ./asql query examples/northwind.sql

-- @report
-- title: Northwind Cloud — Growth Monitor
-- subtitle: Segment health and the case for reallocating two GTM hires
-- format: dashboard
-- author: Analytics
-- brand: Northwind Cloud
-- date-range: Sep 2024 – Aug 2026
-- generated-date: 2026-08-27
-- refreshed-at: Aug 27, 2026 08:00
-- dataset-version: synthetic-v1
-- max-width: 1200px
-- toc: true
-- filter: segment

-- @setup
CREATE OR REPLACE VIEW segment_month     AS FROM 'examples/data/segment_month.csv';
CREATE OR REPLACE VIEW mrr_monthly       AS FROM 'examples/data/mrr_monthly.csv';
CREATE OR REPLACE VIEW nrr_monthly       AS FROM 'examples/data/nrr_monthly.csv';
CREATE OR REPLACE VIEW accounts          AS FROM 'examples/data/accounts.csv';
CREATE OR REPLACE VIEW region_plan       AS FROM 'examples/data/region_plan.csv';
CREATE OR REPLACE VIEW segment_economics AS FROM 'examples/data/segment_economics.csv';
CREATE OR REPLACE VIEW pipeline          AS FROM 'examples/data/pipeline.csv';
CREATE OR REPLACE VIEW smb_cohorts       AS FROM 'examples/data/smb_cohorts.csv';
CREATE OR REPLACE VIEW mrr_projection    AS FROM 'examples/data/mrr_projection.csv';

-- @section: hero
-- label: Summary
-- layout: hero

-- @markdown

-- ## Northwind Cloud — segment health
-- 
-- Tracks MRR, net revenue retention, churn, and pipeline by customer segment. Blended NRR
-- sits near 112%, carried by Enterprise; the segment and cohort views below break down where
-- retention is gaining and where it is leaking. For the decision this data supports, see the
-- `growth_review` memo.

-- @chart: trend
-- title: Blended net revenue retention (%)
-- target: 100 | Breakeven | #8a8a8a
-- y-label: NRR %

SELECT month AS date, blended_nrr AS value FROM nrr_monthly ORDER BY 1;


-- @section: kpis
-- label: The four numbers behind the ask
-- layout: kpi-grid

-- @chart: kpi
-- title: Ending MRR
-- format: dollar
-- target: 1800000 | of Q4 target
-- delta-field: change
-- delta-label: vs 12 mo ago

SELECT ending_mrr AS value,
    ending_mrr - (SELECT ending_mrr FROM mrr_monthly WHERE i = 11) AS change
FROM mrr_monthly WHERE i = 23;

-- @chart: kpi
-- title: Blended NRR
-- delta-field: change
-- delta-label: pts vs 12 mo ago

SELECT blended_nrr AS value,
    ROUND(blended_nrr - (SELECT blended_nrr FROM nrr_monthly WHERE i = 11), 1) AS change
FROM nrr_monthly WHERE i = 23;

-- @chart: kpi
-- title: SMB gross churn (monthly %)
-- delta-field: change
-- delta-label: pts vs 12 mo ago
-- delta-neutral: true

SELECT ROUND(gross_churn_rate, 1) AS value,
    ROUND(gross_churn_rate
        - (SELECT gross_churn_rate FROM segment_month WHERE segment = 'SMB' AND i = 11), 1) AS change
FROM segment_month WHERE segment = 'SMB' AND i = 23;

-- @chart: kpi
-- title: Enterprise share of MRR %
-- delta-field: change
-- delta-label: pts vs 12 mo ago

SELECT
    ROUND(100.0 * SUM(mrr) FILTER (WHERE segment = 'Enterprise') / SUM(mrr), 1) AS value,
    ROUND(100.0 * SUM(mrr) FILTER (WHERE segment = 'Enterprise') / SUM(mrr)
        - (SELECT 100.0 * SUM(mrr) FILTER (WHERE segment = 'Enterprise') / SUM(mrr)
           FROM segment_month WHERE i = 11), 1) AS change
FROM segment_month WHERE i = 23;

-- @section: evidence
-- label: Segment health
-- layout: two-col

-- @chart: bullet
-- title: Quarter attainment vs target
-- format: pct
-- bands: 0.7, 0.9, 1.15

SELECT * FROM (VALUES
    ('Ending MRR', 1675680.0 / 1800000.0, 1.0),
    ('Net new logos', 0.88, 1.0),
    ('Blended NRR', 1.123 / 1.10, 1.0),
    ('SMB retention', 0.895 / 0.95, 1.0)
) AS t(dimension, value, target);

-- @chart: trend
-- title: Enterprise net revenue retention (%)
-- target: 100 | Breakeven | #8a8a8a
-- y-label: NRR %
-- show-points: true

SELECT month AS date, enterprise_nrr AS value FROM nrr_monthly ORDER BY 1;

-- @chart: trend
-- title: SMB monthly gross revenue churn (%)
-- event: 2025-06-01 | Self-serve plan launched | #b3261e
-- y-label: Gross churn %

SELECT month AS date, gross_churn_rate AS value
FROM segment_month WHERE segment = 'SMB' ORDER BY 1;

-- @chart: waterfall
-- title: MRR bridge — full period

SELECT * FROM (VALUES
    ('Starting MRR', 480000.0, 1),
    ('New business', (SELECT ROUND(SUM(new_mrr)) FROM mrr_monthly), 0),
    ('Expansion', (SELECT ROUND(SUM(expansion_mrr)) FROM mrr_monthly), 0),
    ('Contraction', (SELECT ROUND(SUM(contraction_mrr)) FROM mrr_monthly), 0),
    ('Churn', (SELECT ROUND(SUM(churned_mrr)) FROM mrr_monthly), 0),
    ('Ending MRR', (SELECT ROUND(ending_mrr) FROM mrr_monthly WHERE i = 23), 1)
) AS t(label, value, is_total);

-- @chart: deviation
-- title: MRR variance vs plan by region
-- format: dollar
-- x-label: Actual minus plan ($)

SELECT region AS dimension, actual_mrr - plan_mrr AS value
FROM region_plan ORDER BY 2;

-- @chart: ranking
-- title: CAC payback by segment (months)
-- y-label: Months

SELECT segment AS dimension, payback_months AS value
FROM segment_economics ORDER BY 2;

-- @chart: comparison
-- title: MRR by segment (latest month)
-- format: dollar

SELECT segment AS dimension, mrr AS value
FROM segment_month WHERE i = 23 ORDER BY 2 DESC;


-- @section: cohorts
-- label: SMB cohort retention
-- layout: sidebar-main

-- @markdown

-- New SMB cohorts keep almost all their revenue through month 1, then drop sharply between
-- months 2 and 4. That pattern points at onboarding and time-to-first-value — not pricing or
-- targeting. It is the workstream that runs alongside the hiring reallocation.

-- @chart: heatmap
-- title: SMB cohort revenue retention (% retained by months since signup)

SELECT months_since_signup, cohort, ROUND(retention_pct) AS value FROM smb_cohorts;


-- @section: segments
-- label: Segment detail
-- layout: two-col

-- @chart: area
-- title: MRR by segment over time
-- format: dollar

SELECT month AS date, segment AS series, mrr AS value
FROM segment_month ORDER BY 1, 2;

-- @chart: relationship
-- title: CAC vs net revenue retention, by account
-- @x: cac
-- @y: nrr
-- fit: true
-- x-label: Customer acquisition cost ($)
-- y-label: Net revenue retention (%)

SELECT cac, nrr, segment FROM accounts;

-- @chart: bubble
-- title: CAC vs NRR, sized by deal size
-- x-label: Customer acquisition cost ($)
-- y-label: Net revenue retention (%)

SELECT cac AS x, nrr AS y, deal_size AS size, segment FROM accounts;


-- @section: outlook
-- label: Outlook
-- layout: two-col

-- @chart: trend
-- title: MRR projection, next 12 months
-- subtitle: Downside dashed; the baseline is the planning number. Scroll the time axis to zoom.
-- format: dollar
-- series-color: baseline #26468a, aggressive #198038, downside #64748b
-- series-dash: downside
-- show-points: true
-- zoom: x

SELECT month AS date, scenario AS series, mrr AS value
FROM mrr_projection ORDER BY 1, 2;

-- @chart: trend
-- title: New MRR with 3-month moving average
-- format: dollar
-- ma-field: new_mrr_ma
-- y-label: New business MRR

SELECT month AS date, new_mrr AS value,
    ROUND(AVG(new_mrr) OVER (ORDER BY i ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS new_mrr_ma
FROM mrr_monthly ORDER BY 1;

-- @chart: composition
-- title: Share of MRR by segment (latest month)
-- format: pct

SELECT segment AS dimension, mrr / SUM(mrr) OVER () AS value
FROM segment_month WHERE i = 23;

-- @chart: bump
-- title: Segment rank by active logos, by quarter
-- y-label: Rank

SELECT
    make_date(2000 + CAST(strftime(month, '%y') AS INT),
        1 + 3 * (CAST(CEIL(EXTRACT(month FROM month) / 3.0) AS INT) - 1), 1) AS date,
    segment AS dimension,
    SUM(logos) AS value
FROM segment_month
GROUP BY 1, 2 ORDER BY 1, 2;

-- @chart: trend
-- title: MRR over time, one panel per segment
-- format: dollar
-- facet: segment

SELECT month AS date, segment, mrr AS value
FROM segment_month ORDER BY 1, 2;


-- @section: appendix
-- label: Appendix
-- layout: tabs

-- @chart: sparkline
-- title: Blended NRR — 24-month shape

SELECT month AS date, blended_nrr AS value FROM nrr_monthly ORDER BY 1;

-- @chart: combo
-- title: Active logos and blended NRR by month
-- y-label: Active logos
-- series-label: Blended NRR (%)

SELECT date_trunc('month', month) AS x, SUM(logos) AS bar,
    ROUND(SUM(mrr * nrr) / SUM(mrr), 1) AS line
FROM segment_month GROUP BY 1 ORDER BY 1;

-- @chart: funnel
-- title: Current pipeline

SELECT stage, value FROM pipeline;

-- @chart: boxplot
-- title: Deal size by segment

SELECT segment AS dimension, deal_size AS value FROM accounts;

-- @chart: distribution
-- title: Distribution of account deal sizes
-- x-label: Deal size ($)

SELECT deal_size AS value FROM accounts;


-- @chart: slopegraph
-- title: Segment MRR: 12 months ago vs now
-- format: dollar

SELECT segment AS dimension,
    CASE WHEN i = 11 THEN 'Then' ELSE 'Now' END AS period,
    ROUND(mrr) AS value
FROM segment_month WHERE i IN (11, 23) ORDER BY 2;

-- @chart: correlation-matrix
-- title: Account metric correlations

SELECT cac, nrr, deal_size FROM accounts;

-- @chart: table
-- title: Quarterly MRR movements

SELECT
    'FY' || strftime(month, '%y') || ' Q' || CAST(CEIL(EXTRACT(month FROM month) / 3.0) AS INT) AS quarter,
    ROUND(SUM(new_mrr)) AS new_biz,
    ROUND(SUM(expansion_mrr)) AS expansion,
    ROUND(SUM(contraction_mrr + churned_mrr)) AS lost,
    ROUND(MAX(ending_mrr)) AS ending_mrr
FROM mrr_monthly
GROUP BY 1 ORDER BY MIN(i);

-- @chart: flow
-- title: Where signups come from, and where they end up

-- '-- @chart: flow' (Sankey): an edge list of 'source'/'from', 'target'/'to', and a
-- numeric 'value'/'metric'. Self-contained - a Sankey's node layout isn't shaped like the
-- rest of this file's segment/month data, so it doesn't read from northwind.sql's tables.
SELECT * FROM (VALUES
    ('Organic',    'Signup',       4000),
    ('Paid Ads',   'Signup',       3000),
    ('Referral',   'Signup',       1500),
    ('Signup',     'SMB',          5000),
    ('Signup',     'Mid-Market',   2500),
    ('Signup',     'Enterprise',   1000),
    ('SMB',        'Retained',     3200),
    ('SMB',        'Churned',      1800),
    ('Mid-Market', 'Retained',     2100),
    ('Mid-Market', 'Churned',      400),
    ('Enterprise', 'Retained',     950),
    ('Enterprise', 'Churned',      50)
) AS t(source, target, value);
