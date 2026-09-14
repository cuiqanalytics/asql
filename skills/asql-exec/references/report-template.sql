-- Executive decision memo — skeleton. Copy this, fill the SQL, delete the guidance
-- comments. Reference implementation: examples/growth_review.sql (and the dashboard
-- companion examples/growth_dashboard.sql) in the asql repo.
--
-- Use format: narrative for a one-time decision read in a room; format: dashboard for a
-- number that will be monitored over time. See references/executive-communication.md.

-- @report
-- title: <takeaway headline: [key metric] + [direction/comparison] + [primary driver] —
--         a specific conclusion, not "Q3 Review" or "Executive Summary">
-- subtitle: <audience + what they're deciding>
-- format: narrative
-- author: <team>
-- brand: <company>
-- date-range: <period the data covers>
-- generated-date: <YYYY-MM-DD>
-- toc: true

-- @setup
-- Define shared views once here so every block's numbers come from the same definition
-- (prevents check #4, inconsistency). CREATE OR REPLACE VIEW ... AS (...);


-- ---------------------------------------------------------------------------
-- 1. BOTTOM LINE  — must be the first thing on the page
-- ---------------------------------------------------------------------------

-- @markdown

-- **Recommendation.** <action verb + specific action + rationale, one sentence>
-- **Cost.** <headcount / dollars / opportunity cost — or "none">
-- **Expected impact.** <tied to revenue, cost, or risk, with a number>
-- **The ask today:** <approve / fund / greenlight / change course>
--
-- Key findings:
-- - <observation + context + implication>
-- - <observation + context + implication>
-- - <observation + context + implication>
--
-- <Data source · time period · main caveat.>

-- Then one KPI or chart block here as the single supporting visual.


-- ---------------------------------------------------------------------------
-- 2. THE NUMBERS BEHIND THE ASK  — 3 to 4 KPIs, each with a delta
-- ---------------------------------------------------------------------------

-- @section: The numbers behind the ask
-- label: The numbers behind the ask
-- layout: kpi-grid

-- @chart: kpi
-- title: <metric>
-- format: dollar
-- delta-field: change
-- delta-label: vs <reference period>

-- SELECT <current> AS value, <current> - <reference> AS change FROM ...;

-- (repeat for the other 2-3 numbers; use delta-neutral: true where "up" isn't good)


-- ---------------------------------------------------------------------------
-- 3. WHY  — one claim, one chart. Two to four of these, no more.
-- ---------------------------------------------------------------------------

-- @section: Why
-- label: Why — the evidence
-- layout: single

-- @markdown
-- title: 1. <claim, stated as a sentence the chart proves>

-- <2-3 sentences of context. Frame in money or units.>

-- @chart: trend
-- title: <what the reader is looking at>
-- target: <value> | <label> |
-- y-label: <units>

-- SELECT <date> AS date, <measure> AS value FROM ... ORDER BY 1;

-- (repeat: claim @markdown then one chart, per supporting point)


-- ---------------------------------------------------------------------------
-- 4. WHAT COULD GO WRONG  — pre-empt the pushback
-- ---------------------------------------------------------------------------

-- @section: What could go wrong
-- label: What could go wrong
-- layout: two-col

-- @markdown

-- **"<objection 1>"** <one-paragraph response>
-- **"<objection 2>"** <one-paragraph response>

-- @chart: <intent>
-- title: <backup evidence for an objection>
-- SELECT ...;


-- ---------------------------------------------------------------------------
-- 5. RECOMMENDATION  — owner, timeline, checkpoints
-- ---------------------------------------------------------------------------

-- @section: Recommendation
-- label: Recommendation
-- layout: single

-- @markdown

-- **Decision requested:** <the ask again, precisely>
--
-- | Step | Owner | By |
-- |---|---|---|
-- | <step> | <role> | <date> |
-- | First checkpoint: <metric to watch> | <role> | <date> |
-- | Go / no-go on <next phase> | <role> | <date> |


-- ---------------------------------------------------------------------------
-- 6. APPENDIX  — methodology and detail, collapsed
-- ---------------------------------------------------------------------------

-- @section: Appendix
-- label: Appendix — supporting detail
-- layout: single
-- collapsible: true

-- @markdown

-- Definitions, data sources, as-of dates, and anything cut from the sections above for
-- length.

-- @chart: table
-- title: <underlying data>
-- SELECT ...;
