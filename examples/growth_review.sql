-- growth_review.sql — Northwind Cloud's Q3 growth review as a written decision memo, and
-- the companion to growth_dashboard.sql (the same data and story as an interactive
-- dashboard). Structure follows "lead with the decision": bottom line first, the numbers
-- behind it, one claim + one chart per section, an objection map, then the recommendation.
-- Prints clean to PDF. Demonstrates narrative format: @narrative templated prose, an
-- embedded @image, KaTeX, and the SVG chart compiler.
--
-- Reads the shared dataset in examples/data/ — regenerate it with
--   ./asql query examples/northwind.sql

-- @report
-- title: Where Northwind Cloud Should Put Its Next Two Hires
-- subtitle: Q3 FY26 growth review — decision memo for the leadership team
-- format: narrative
-- author: Analytics
-- brand: Northwind Cloud
-- date-range: Sep 2024 – Aug 2026
-- generated-date: 2026-08-27
-- dataset-version: synthetic-v1
-- toc: true

-- @setup
CREATE OR REPLACE VIEW segment_month     AS FROM 'examples/data/segment_month.csv';
CREATE OR REPLACE VIEW mrr_monthly       AS FROM 'examples/data/mrr_monthly.csv';
CREATE OR REPLACE VIEW nrr_monthly       AS FROM 'examples/data/nrr_monthly.csv';
CREATE OR REPLACE VIEW accounts          AS FROM 'examples/data/accounts.csv';
CREATE OR REPLACE VIEW region_plan       AS FROM 'examples/data/region_plan.csv';
CREATE OR REPLACE VIEW segment_economics AS FROM 'examples/data/segment_economics.csv';
CREATE OR REPLACE VIEW pipeline          AS FROM 'examples/data/pipeline.csv';
CREATE OR REPLACE VIEW smb_cohorts       AS FROM 'examples/data/smb_cohorts.csv';

-- @markdown

-- **Recommendation.** Move our two open go-to-market hires from SMB new-business into
-- Mid-Market expansion, starting next quarter.
-- 
-- **Cost.** Zero incremental headcount — this is a reallocation of roles already budgeted.
-- 
-- **Expected impact.** SMB is now destroying about $0.68 of recurring revenue through churn
-- for every $1 of new business it adds, and its net revenue retention has fallen below 90%.
-- Mid-Market and Enterprise both retain above 105% and expand efficiently. Redirecting the
-- two hires shifts roughly $0.9M of annual gross-retention risk toward the segments that
-- compound, and is expected to lift blended NRR by 2-3 points within four quarters.
-- 
-- **The ask today:** approve the reallocation so recruiting can re-scope the two roles this
-- week.

-- @image
-- title: How a customer becomes recurring revenue
-- path: assets/acquisition_flow.svg
-- caption: The three stages this memo tracks. The reallocation targets stage 3 — expansion.
-- height: 150px

-- @section: The numbers behind the ask
-- label: The numbers behind the ask
-- layout: kpi-grid

-- @chart: kpi
-- title: Ending MRR
-- format: dollar
-- target: 1800000 | of Q4 target
-- delta-field: change
-- delta-label: vs 12 mo ago

SELECT
    ending_mrr AS value,
    ending_mrr - (SELECT ending_mrr FROM mrr_monthly WHERE i = 11) AS change
FROM mrr_monthly WHERE i = 23;

-- @chart: kpi
-- title: Blended NRR
-- delta-field: change
-- delta-label: pts vs 12 mo ago

SELECT
    blended_nrr AS value,
    ROUND(blended_nrr - (SELECT blended_nrr FROM nrr_monthly WHERE i = 11), 1) AS change
FROM nrr_monthly WHERE i = 23;

-- @chart: kpi
-- title: SMB gross churn (monthly %)
-- delta-field: change
-- delta-label: pts vs 12 mo ago
-- delta-neutral: true

SELECT
    ROUND(gross_churn_rate, 1) AS value,
    ROUND(gross_churn_rate
        - (SELECT gross_churn_rate FROM segment_month WHERE segment = 'SMB' AND i = 11), 1) AS change
FROM segment_month WHERE segment = 'SMB' AND i = 23;

-- @chart: kpi
-- title: Enterprise share of MRR %
-- delta-field: change
-- delta-label: pts vs 12 mo ago

SELECT
    ROUND(100.0 * SUM(mrr) FILTER (WHERE segment = 'Enterprise') / SUM(mrr), 1) AS value,
    ROUND(
        100.0 * SUM(mrr) FILTER (WHERE segment = 'Enterprise') / SUM(mrr)
        - (SELECT 100.0 * SUM(mrr) FILTER (WHERE segment = 'Enterprise') / SUM(mrr)
           FROM segment_month WHERE i = 11), 1) AS change
FROM segment_month WHERE i = 23;



-- @section: Why
-- label: Why — the evidence
-- layout: single

-- @markdown

-- Each claim below is followed by the single chart that supports it. Nothing here needs more
-- than one look.

-- @markdown
-- title: 1. Enterprise retention is carrying the business — and still climbing

-- Enterprise net revenue retention has risen from 112% to 123% over the last two years and
-- has been above the 120% mark since early this year. Anything above 100% means the segment
-- grows even with zero new logos.

-- @chart: trend
-- title: Enterprise net revenue retention (%)
-- target: 100 | Breakeven — no net churn | #8a8a8a
-- y-label: NRR %

SELECT month AS date, enterprise_nrr AS value FROM nrr_monthly ORDER BY 1;

-- @markdown
-- title: 2. SMB gross churn has roughly doubled in twelve months

-- SMB monthly gross revenue churn has gone from 1.7% to 3.4% since we launched the
-- self-serve plan — an annualized loss rate approaching 35% of that segment's recurring
-- revenue.

-- @chart: trend
-- title: SMB monthly gross revenue churn (%)
-- event: 2025-06-01 | Self-serve plan launched | #b3261e
-- y-label: Gross churn %

SELECT month AS date, gross_churn_rate AS value
FROM segment_month WHERE segment = 'SMB' ORDER BY 1;

-- @markdown
-- title: 3. Churn now cancels two-thirds of new business every month

-- The MRR bridge for the full period still nets strongly positive, but the churn bar has
-- grown faster than any other component. In the most recent month, lost MRR equals about
-- 68% of new-business MRR — up from under 20% two years ago.

-- @chart: waterfall
-- title: MRR bridge, Sep 2024 to Aug 2026

SELECT * FROM (VALUES
    ('Starting MRR', 480000.0, 1),
    ('New business', (SELECT ROUND(SUM(new_mrr)) FROM mrr_monthly), 0),
    ('Expansion', (SELECT ROUND(SUM(expansion_mrr)) FROM mrr_monthly), 0),
    ('Contraction', (SELECT ROUND(SUM(contraction_mrr)) FROM mrr_monthly), 0),
    ('Churn', (SELECT ROUND(SUM(churned_mrr)) FROM mrr_monthly), 0),
    ('Ending MRR', (SELECT ROUND(ending_mrr) FROM mrr_monthly WHERE i = 23), 1)
) AS t(label, value, is_total);

-- @markdown
-- title: 4. SMB churn is a month-2-to-4 problem, not a day-1 problem

-- New SMB cohorts hold nearly all their revenue through the first month, then fall off a
-- cliff between months two and four. That points at onboarding and first-value, not at
-- pricing or targeting.

-- @chart: heatmap
-- title: SMB cohort revenue retention (% retained by months since signup)

SELECT months_since_signup, cohort, ROUND(retention_pct) AS value FROM smb_cohorts;



-- @section: Where the two hires go
-- label: Where the two hires should go
-- layout: single

-- @markdown

-- The problem is SMB retention. The two levers that follow decide where the reallocated
-- headcount lands.

-- @markdown
-- title: Mid-Market recovers acquisition cost fastest

-- CAC payback is 9 months in Mid-Market versus 14 in SMB and 16 in Enterprise. Combined with
-- above-100% net revenue retention, an added Mid-Market rep pays back soonest.

-- @chart: ranking
-- title: CAC payback by segment (months)
-- y-label: Months to recover CAC

SELECT segment AS dimension, payback_months AS value
FROM segment_economics ORDER BY 2;

-- @markdown
-- title: EMEA is the one region behind plan — and where the reps sit

-- EMEA is 8% below its MRR plan while every other region is ahead. It is also where two of
-- our strongest Mid-Market expansion reps sit today, so the reallocation can be staffed
-- without relocating anyone.

-- @chart: deviation
-- title: MRR vs plan by region
-- format: dollar
-- x-label: Actual minus plan ($)

SELECT region AS dimension, actual_mrr - plan_mrr AS value
FROM region_plan ORDER BY 2;



-- @section: What could go wrong
-- label: What could go wrong
-- layout: two-col

-- @markdown

-- **"SMB is still growing — why pull support?"** It is, but only just, and the trend line is
-- against us. The reallocation keeps SMB self-serve intact; it removes two *outbound
-- new-business* roles whose payback has stretched past a year.
-- 
-- **"Two reps won't move the Mid-Market number."** On current Mid-Market economics (9-month
-- payback, 106% NRR) two quota-carrying reps model to roughly $0.6-0.8M net-new ARR within
-- four quarters — enough to offset the SMB gross-retention risk we are accepting.
--
-- **"Enterprise is the real opportunity."** Enterprise retains best but has a 16-month
-- payback and a long sales cycle; it is a hiring plan for next fiscal year, not a
-- reallocation we can make this quarter.

-- @chart: relationship
-- title: Higher-touch accounts retain better (CAC vs NRR, by account)
-- @x: cac
-- @y: nrr
-- fit: true
-- x-label: Customer acquisition cost ($)
-- y-label: Net revenue retention (%)

SELECT cac, nrr, segment FROM accounts;

-- @chart: boxplot
-- title: Deal size by segment

SELECT segment AS dimension, deal_size AS value FROM accounts;



-- @section: Recommendation
-- label: Recommendation
-- layout: single

-- @markdown

-- **Decision requested:** approve moving the two open GTM req's from SMB new-business to
-- Mid-Market expansion.
-- 
-- | Step | Owner | By |
-- |---|---|---|
-- | Re-scope the two reqs, notify recruiting | VP Sales | This week |
-- | Reassign the two EMEA Mid-Market accounts pending backfill | RVP EMEA | 2 weeks |
-- | Stand up an SMB month-2 onboarding intervention (separate workstream) | Head of CS | 30 days |
-- | First checkpoint: Mid-Market pipeline created, SMB month-2 retention | Analytics | 60 days |
-- | Go / no-go on a second wave of reallocation | Leadership | End of Q4 |

-- @chart: funnel
-- title: Current Mid-Market-weighted pipeline (the base we are trying to grow)

SELECT stage, value FROM pipeline;



-- @section: Appendix
-- label: Appendix — supporting detail
-- layout: single
-- collapsible: true

-- @markdown

-- Full detail behind the summary charts. Not required reading for the decision.

-- @narrative
-- title: Scale of the period

SELECT
    ROUND((SELECT SUM(mrr) FROM segment_month WHERE i = 23) / 1e6, 2) AS ending_mrr_m,
    ROUND(100.0 * (SELECT SUM(mrr) FROM segment_month WHERE i = 23)
        / (SELECT SUM(mrr) FROM segment_month WHERE i = 0) - 100) AS growth_pct,
    (SELECT COUNT(*) FROM accounts) AS accounts;

-- Over the 24 months in view, MRR grew **{{ growth_pct }}%** to **\${{ ending_mrr_m }}M**
-- across {{ accounts }} tracked accounts.

-- @chart: area
-- title: MRR by segment over time
-- format: dollar

SELECT month AS date, segment AS series, mrr AS value
FROM segment_month ORDER BY 1, 2;

-- @chart: combo
-- title: Active logos and blended NRR by month
-- y-label: Active logos
-- series-label: Blended NRR (%)

SELECT date_trunc('month', month) AS x,
    SUM(logos) AS bar,
    ROUND(SUM(mrr * nrr) / SUM(mrr), 1) AS line
FROM segment_month GROUP BY 1 ORDER BY 1;

-- @chart: distribution
-- title: Distribution of account deal sizes
-- x-label: Deal size ($)

SELECT deal_size AS value FROM accounts;

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

-- @narrative
-- title: One-paragraph summary

SELECT
    (SELECT ROUND(ending_mrr / 1000.0) FROM mrr_monthly WHERE i = 23) AS mrr_k,
    (SELECT blended_nrr FROM nrr_monthly WHERE i = 23) AS nrr,
    (SELECT ROUND(gross_churn_rate, 1) FROM segment_month WHERE segment = 'SMB' AND i = 23) AS smb_churn;

-- Northwind Cloud ended the period at ${{ mrr_k }}K MRR with blended NRR of {{ nrr }}%.
-- The single largest risk to that number is SMB gross churn, now {{ smb_churn }}% per
-- month. The recommended reallocation of two GTM hires into Mid-Market expansion is the
-- fastest no-cost lever available to protect and compound recurring revenue.
