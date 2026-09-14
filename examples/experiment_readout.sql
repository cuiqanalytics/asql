-- experiment_readout.sql — an A/B test readout as a decision doc. Self-contained: the
-- weekly numbers are inline VALUES, so this file needs no shared dataset. Demonstrates
-- confidence bands (`ci:` on a trend), error-bar whiskers (`ci:` on a comparison), an
-- x-anchored `annotation:`, a partial-width `segment:`, and a build-time `refreshed-at`.

-- @report
-- title: Checkout Redesign — Experiment Readout
-- subtitle: A/B test · new checkout flow vs. holdout · 8 weeks
-- author: Experimentation
-- experiment-id: EXP-2043
-- date-range: Jun 2 – Jul 27, 2026
-- refreshed-at: = CURRENT_DATE
-- dataset-version: synthetic-v1
-- max-width: 1200px
-- toc: true

-- @setup
CREATE OR REPLACE VIEW weekly AS (
    SELECT
        week::DATE            AS week,
        arm,
        cvr,
        cvr - ci_halfwidth   AS cvr_low,
        cvr + ci_halfwidth   AS cvr_high,
        rev_per_session
    FROM (VALUES
        ('2026-06-02', 'treatment', 0.0401, 0.0030, 2.71),
        ('2026-06-09', 'treatment', 0.0419, 0.0027, 2.78),
        ('2026-06-16', 'treatment', 0.0433, 0.0024, 2.83),
        ('2026-06-23', 'treatment', 0.0447, 0.0022, 2.86),
        ('2026-06-30', 'treatment', 0.0456, 0.0021, 2.90),
        ('2026-07-07', 'treatment', 0.0461, 0.0020, 2.92),
        ('2026-07-14', 'treatment', 0.0468, 0.0019, 2.95),
        ('2026-07-21', 'treatment', 0.0459, 0.0019, 2.91),
        ('2026-06-02', 'holdout',   0.0398, 0.0031, 2.70),
        ('2026-06-09', 'holdout',   0.0405, 0.0028, 2.72),
        ('2026-06-16', 'holdout',   0.0396, 0.0025, 2.69),
        ('2026-06-23', 'holdout',   0.0402, 0.0023, 2.73),
        ('2026-06-30', 'holdout',   0.0409, 0.0022, 2.74),
        ('2026-07-07', 'holdout',   0.0401, 0.0021, 2.71),
        ('2026-07-14', 'holdout',   0.0397, 0.0020, 2.70),
        ('2026-07-21', 'holdout',   0.0404, 0.0020, 2.72)
    ) AS t(week, arm, cvr, ci_halfwidth, rev_per_session)
);

-- @markdown
-- title: Bottom line

-- **Recommendation — ship the redesign to 100%.** The new checkout flow lifts
-- conversion by **+13.8% relative** (4.60% vs 4.04%, 95% CI +8.1% to +19.6%) with no
-- movement on the revenue-per-session guardrail. The weekly bands separate cleanly from
-- week 4 on.
--
-- - Effect is **strongest on mobile** (+18.1%) and holds on desktop (+9.3%); tablet is
--   inconclusive (CI crosses zero) but low-volume.
-- - Revenue per session tracks the conversion gain — no evidence of smaller baskets.
-- - 248k sessions over 8 weeks; the interval has been stable and above zero for 4 weeks.
--
-- Data: `weekly` view · Jun 2 – Jul 27, 2026 · conversion = completed orders / checkout
-- sessions. Bands are 95% normal-approx intervals computed upstream.

-- @section: The numbers
-- label: The numbers behind the call
-- layout: kpi-grid

-- @chart: kpi
-- title: Conversion lift (relative)
-- format: pct
-- delta-field: change
-- delta-label: vs. holdout

SELECT 0.1386 AS value, 0.1386 AS change;

-- @chart: kpi
-- title: Treatment conversion
-- format: pct
-- delta-field: change
-- delta-label: vs. holdout (pp)

SELECT 0.0460 AS value, 0.0056 AS change;

-- @chart: kpi
-- title: Sessions in test

SELECT 248000 AS value;

-- @chart: kpi
-- title: Weeks interval held above 0

SELECT 4 AS value;

-- @section: Weekly conversion
-- label: Weekly conversion, with 95% bands
-- layout: single

-- @chart: trend
-- title: Checkout conversion by arm
-- subtitle: Shaded band = 95% CI. Where the bands stop overlapping, the arms are separated.
-- ci: cvr_low | cvr_high
-- format: pct
-- annotation: 2026-06-16 | Ramp to 50% traffic | #8a489e
-- segment: 0.046 | 2026-07-07 | 2026-07-21 | Target 4.6% | #26468a

SELECT week AS date, arm AS series, cvr AS value, cvr_low, cvr_high
FROM weekly
ORDER BY week, arm;

-- @section: By segment
-- label: Lift by device
-- layout: single

-- @chart: comparison
-- title: Relative conversion lift by device
-- subtitle: Whiskers = 95% CI of the lift. Tablet crosses zero — inconclusive.
-- ci: lift_low | lift_high
-- format: pct

SELECT * FROM (VALUES
    ('Mobile',  0.181, 0.124, 0.238),
    ('Desktop', 0.093, 0.041, 0.145),
    ('Tablet',  0.062, -0.020, 0.144)
) AS t(dimension, value, lift_low, lift_high);

-- @section: Guardrail
-- label: Revenue-per-session guardrail
-- layout: single

-- @chart: trend
-- title: Revenue per session by arm
-- subtitle: Should move with conversion, not against it — a smaller-basket regression would show here.
-- format: dollar

SELECT week AS date, arm AS series, rev_per_session AS value
FROM weekly
ORDER BY week, arm;

-- @section: Appendix
-- label: Appendix — weekly data
-- layout: single
-- collapsible: true

-- @chart: table
-- title: Weekly conversion and guardrail

SELECT
    week,
    arm,
    ROUND(cvr * 100, 2)          AS "cvr %",
    ROUND(cvr_low * 100, 2)      AS "ci low %",
    ROUND(cvr_high * 100, 2)     AS "ci high %",
    ROUND(rev_per_session, 2)    AS "rev/session"
FROM weekly
ORDER BY week, arm;
