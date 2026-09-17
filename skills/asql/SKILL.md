---
name: asql
description: Use when the user asks for a dashboard, report, or chart built from SQL or a data file ("I want a dashboard that shows...", "build me a report on..."), or when writing/editing a .sql file meant to be built with the asql CLI tool. Covers asql's annotated-SQL `-- @` block syntax, chart intents, and the column-naming conventions the tool auto-detects.
---

# Building asql Reports

## Overview

`asql` turns a `.sql` file annotated with `-- @` comment blocks into a self-contained HTML
report — `asql build report.sql` writes `report.sql` → `report.html`, no server needed. The
file stays valid, runnable SQL throughout: asql reads structure from `--`-prefixed
comments, chart type from `-- @chart: <intent>`, and axes/series from your `SELECT`
column names.

## Workflow

1. Confirm the data source (anything DuckDB can read — CSV, Parquet, another DuckDB file —
   see `reference.md`) and what the user actually wants shown.
2. Pick one `-- @chart: <intent>` per visual from the table below — usually `trend` (time
   series), `ranking` (top-N), `kpi` (headline number), or `comparison` (categories).
3. Name `SELECT` columns using the conventions below so asql infers axes without manual
   overrides.
4. Wrap it in a `-- @report` header block. Group related charts with `-- @section:` once
   there are more than ~4.
5. Run `asql build <file>.sql` (or `asql preview <file>.sql` while iterating) and check for
   red diagnostic cards — a broken block never breaks the rest of the report, but it means
   an intent/column mismatch needs fixing.

For anything beyond the basics — explicit `@x`/`@y`/`@series` overrides, reference lines,
KPI deltas, moving averages, per-series colour/line-style (`series-color`/`series-dash`),
opt-in zoom/pan (`-- zoom: xy` on trend/area/scatter/bubble),
narrative-format (print-style) reports, `@markdown`/`@image` blocks, LaTeX math
(`$…$` / `$$…$$`) in prose, interactive `-- filter:`/`-- slider:`/`-- slider-range:`
controls and `layout: tabs` sections (dashboard), click-to-sort `table` columns
(automatic, no annotation needed), Few-style scorecard decorations
(`lights`, `status`/`target`/`delta`/`spark` columns) on `table`/`kpi`, report/section
metadata, shared setup SQL (`@setup`, so you're not repeating the same CTE in every
block), or theming — read `reference.md` in this skill's directory before guessing at
syntax.

## Minimal example

```sql
-- @report
-- title: Revenue Dashboard
-- subtitle: Last 12 months

-- @chart: trend
-- title: Revenue Over Time

SELECT
    DATE_TRUNC('month', order_date) AS date,
    channel AS series,
    SUM(revenue) AS value
FROM read_csv_auto('orders.csv')
GROUP BY 1, 2
ORDER BY 1;

-- @chart: kpi
-- title: Total Revenue

SELECT SUM(revenue) AS value FROM read_csv_auto('orders.csv');
```

`asql build revenue.sql` → `revenue.html`, a single file, open it in a browser.

## Chart intents

| Intent | Use for | Produces |
|---|---|---|
| `auto` | Let asql decide | 1 row + 1-6 measures → KPI; else temporal col → trend; else categorical → ranking; else table |
| `trend` | A measure over time | Line chart (multi-series folds top 8 into "Other") |
| `area` | Measure over time, filled | Same resolution as `trend`; multi-series stacks |
| `comparison` | How a few categories compare on one measure | Vertical bars (≤5) / horizontal (6+), sorted by value |
| `ranking` | Where an item sits in an ordered list (top/bottom-N) | Horizontal bars, kept in SQL row order |
| `deviation` | Signed variance from a reference (vs plan, YoY) | Diverging bars around 0, green/red by sign — pass `actual - plan AS value` |
| `bullet` | Actual vs target vs bands (goal tracking) | Bar + tick over graded bands — needs `value` + `target`; `bands: 60, 80, 120` |
| `slopegraph` | Before/after across categories (two periods) | One line per category between two x positions |
| `bump` | Rank over time | One line per category on an inverted rank axis (asql ranks per period) |
| `correlation-matrix` | Pairwise correlation of many numeric columns | Diverging heatmap of Pearson r — pass a wide numeric result |
| `distribution` | Spread of **one** numeric column | Histogram (diagnostic if a categorical col is also present — use `boxplot`) |
| `boxplot` | Spread of a numeric column **across categories** | Box plot |
| `composition` | Parts of a whole | Pie (≤3 slices) / 100%-stacked bar (4+) / stacked area (with a date col) |
| `relationship` | Correlation between two numeric columns | Scatter plot (coloured by a `series`/`color` or spare categorical column) |
| `bubble` | Three numeric variables at once | Scatter + point size from a third measure — needs `x`, `y`, `size` (alias `AS size`); optional `series` colours |
| `sparkline` | The shape of a series at a glance | Tiny axis-less line (~48px) — ordered dimension + one measure, single-series |
| `heatmap` | Measure across two categorical dimensions | Grid heatmap (sequential; `scale: diverging` for change data) |
| `combo` | Two measures, shared axis | Dual-axis bar+line — columns `x`, `bar`, `line`, or `@x: <col>` + two measures |
| `funnel` | Stage-by-stage drop-off | Horizontal bars — stage column (alias `stage`) + a measure; shows step conversion |
| `waterfall` | Cumulative build-up/breakdown | Floating bars — `label`/`dimension` + `value`; `is_total` optional (else first/last are totals) |
| `flow` | Volume moving between stages/entities | Sankey diagram — edge list: `source`/`from`, `target`/`to`, numeric `value`/`metric`; dashboard only, raw Vega v5 spec, a cycle/self-loop is a diagnostic |
| `kpi` | One headline number | Big number (1 col), tile row (2-6 cols), or table (7+) |
| `table` | Anything else / raw results | Formatted table (auto-paginated if the result is large) |

## Column naming (so asql infers axes automatically)

| Alias | Meaning |
|---|---|
| `date` | Temporal axis |
| `dimension`, `label` | Categorical axis (`dimension` is checked first — prefer it unless the intent requires `label` specifically, e.g. `waterfall`) |
| `series`, `color` | Grouping/series |
| `value`, `metric` | The measure |
| `x`, `y` | Explicit axes (also the names used by `@x`/`@y` overrides) |
| `size` | `bubble` only — the measure driving point size |
| `target` | `bullet` — the target measure |
| `source`, `from` | `flow` — the edge's origin node |
| `target`, `to` | `flow` — the edge's destination node (a different `target` than `bullet`'s) |

Without these names, asql infers from SQL types (a `DATE` column → temporal, a numeric
column with many distinct values → measure) and finally from column order. When inference
would plausibly guess wrong, name the columns explicitly rather than fighting it with
overrides — it's cheaper.

## Verify

Always run `asql build` (or check the `asql preview` page) after writing or editing a
report. A bad chart intent/column mismatch renders as a red diagnostic card with a message
explaining what was detected, not a build failure — easy to miss if you don't look.

To sanity-check raw SQL without the report pipeline, `asql query <file>.sql` runs a flat
`.sql` file and prints the rows as a table (`--format csv` for CSV). It ignores `-- @`
blocks entirely, including `@setup`, so a report file that depends on setup views will
error — point it at a scratch `.sql` or a self-contained query.
