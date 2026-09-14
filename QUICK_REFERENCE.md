# asql Quick Reference

A `.sql` file annotated with `-- @<type>` comment blocks, built with `asql build report.sql`
→ `report.html`. The file stays valid, runnable SQL throughout. This sheet lists every
block type, key, and flag with an inline example — see `TUTORIAL.md` for a walkthrough.

## CLI

```bash
asql build report.sql                          # writes report.html next to it
asql build --fresh report.sql                  # ignore the query-result cache
asql build --theme themes/midnight.css report.sql
asql preview report.sql                        # live-reload dev server, default port 4321
asql preview --port 4321 report.sql
asql preview --theme themes/sepia.css report.sql
asql query query.sql                           # run a flat .sql file, print rows as a table
asql query --format csv query.sql              # ...as CSV
```

Flags go **before** the file path (`asql preview report.sql --port 4321` silently falls back
to the default port instead of erroring).

`asql query` runs a flat `.sql` file through DuckDB and prints the result
set. It ignores `-- @` blocks entirely (they're just SQL comments, `@setup` included);
DuckDB runs every statement and you get back only the **last** statement's rows, not all of
them. Duplicate output column names collapse (a pre-existing `exec` limitation) — alias them
distinctly. Point it at a scratch `.sql` or a self-contained query.

## `-- @report` — report-level metadata (no SQL, one per file)

```sql
-- @report
-- title: Revenue Dashboard
-- subtitle: Last 12 months
-- layout: grid_2x2
-- format: dashboard
-- description: Q2 performance vs. plan
-- author: Analytics Team
-- brand: Acme Analytics
-- team: Growth & Insights
-- date-range: Apr 1 - Jun 30, 2026
-- experiment-id: EXP-1042
-- generated-date: 2026-06-30
-- refreshed-at: Aug 24, 2026 09:00
-- dataset-version: synthetic-v1
-- max-width: 1200px
-- toc: true
```

| Key | Values / example | Effect |
|---|---|---|
| `title` | `Revenue Dashboard` | Masthead `<h1>`. |
| `subtitle` | `Last 12 months` | Masthead subheading. |
| `layout` | `single` (default), `grid_2x2`, `grid_3x2` | Report-wide grid, unless overridden per `@section`. |
| `format` | `dashboard` (default) or `narrative` | `dashboard` = interactive Vega-Lite charts; `narrative` = print-style, single-column, static SVG, serif body. |
| `description` | free text | Longer blurb (not always rendered; informational). |
| `author`, `brand`, `team`, `date-range`, `experiment-id`, `generated-date`, `dataset-version` | free text | Small chrome text in the masthead, all optional. |
| `refreshed-at` | `Aug 24, 2026 09:00` | Dashboard-only: floating "Updated `<value>`" badge, top-right of the masthead — distinct from `generated-date`'s chrome text. A value with a leading `= ` (e.g. `= CURRENT_TIMESTAMP`) is a SQL scalar expression evaluated at build time; its result replaces the string. A failed expression degrades to `unavailable` rather than breaking the build. |
| `max-width` | `1200px` | Caps the content column width (dashboard format only). |
| `toc` | `true` | Table of contents from every labeled `@section:` — floating sidebar (dashboard, wide viewports only) or an inline block near the top (narrative). Static jump-links, no scroll-position highlighting. |
| `filter` | `region` or `region; channel` | Interactive filters — see below. |
| `filter-exclusive` | `region` | Drops the "All" option from a `filter` dropdown, forcing the browser's default first value. Same `;`/`,`-separated column list shape as `filter`; a column must also be listed in `filter` to have any effect. |
| `slider` | `region` | Discrete slider instead of a dropdown — same participation rules as `filter`; a column can't be in both `filter` and `slider`. |
| `slider-range` | `deal_size` | Min/max range slider on a numeric column — two thumbs, one signal (`10..90`). Same participation rules as `filter`. |

### `-- filter:` — interactive chart filters

`-- filter: region` renders a sticky control bar with a `region` dropdown (All + every
distinct value across the charts). Changing it re-filters every chart live in the browser
(client-side Vega signals — no rebuild).

- Each participating chart's `SELECT` **must project the filter column** — under its own
  name or aliased (`region AS series`). asql matches `-- filter: region` against the result
  column name and against a plain `region AS <alias>` in the query. A chart that doesn't
  project it (or only computes it) is left alone — it just won't respond to that dropdown.
- KPIs, tables, and `funnel` / `waterfall` / `bump` / `correlation-matrix` never filter
  (the bar's note reads "filters charts only"). `flow` never filters either — it's a raw
  Vega spec with no `-- filter:`/`-- slider:` signal wiring at all.
- Multiple columns: separate with `;` or `,`; they AND together.
- The selection is mirrored to the URL hash (`#region=East&channel=paid`) — that URL is a
  shareable deep link; reopening it restores the dropdowns before the charts render.
- Legend-click isolation on multi-series charts is automatic and independent of `filter`:
  click a legend entry to isolate that series (others are hidden, not dimmed); shift-click to
  toggle one series; clear the selection to restore all.

### `-- slider:` / `-- slider-range:` — the same filter bar, as sliders

`-- slider: region` renders the same `region` control as a discrete range-input slider
(drag or arrow keys through All + every distinct value) instead of a `<select>` dropdown —
same participation rule as `filter` (the chart must project the column), same `flt_region`
signal, same URL-hash sync. Good for a handful of ordered values where stepping through
beats a dropdown.

`-- slider-range: deal_size` renders a min/max range slider (two thumbs) over a numeric
column's data-min..data-max instead. It writes one signal holding `"min..max"` (or
`"__ALL__"`), and the participating chart's filter transform becomes a numeric range check
rather than an equality check. The URL hash carries it as `#deal_size=300..12000`.

A column can be in `filter`, `slider`, or `slider-range` — never more than one of the three.

## `-- @setup` — runs once before every block's query, no card of its own

```sql
-- @setup
CREATE OR REPLACE VIEW orders AS (
    SELECT * FROM read_csv_auto('orders.csv') WHERE status != 'cancelled'
);
```

Plain SQL, no metadata, placed right after `-- @report`. Use `CREATE OR REPLACE` (not plain
`CREATE`) — it re-runs before *every* block's query, not once per report: a full build
shares one connection across all blocks, but each preview-mode block editor opens its own
fresh isolated connection per request and needs to see the setup again. Multiple
`-- @setup` blocks are allowed and run in document order.

## `-- @section: <name>` — splits the report into independently laid-out groups

```sql
-- @section: overview
-- label: Overview
-- layout: two-col
-- collapsible: true

-- @chart: trend
...
```

| Key | Values | Effect |
|---|---|---|
| `label` | `Overview` | Heading shown above the section. |
| `layout` | `single`, `full`, `grid_2x2`/`two-col`, `grid_3x2`/`three-col`, `kpi-grid`, `sidebar-main`, `hero`, `tabs` | This section's grid, overrides the report-level `layout`. |
| `collapsible` | `true` | Renders as a collapsible `<details>`. |

`layout: tabs` on a multi-card section renders the cards as tabs (tab label = each card's
title); a one-card `tabs` section falls back to the normal single-column layout. A chart
on an unopened tab renders on first switch. Narrative format ignores `tabs` — dashboard-only.

Skip `@section` entirely and every block lands in one implicit section.

## `-- @chart: <intent>` — one visual, metadata then one SQL statement

```sql
-- @chart: trend
-- title: Monthly Revenue
-- subtitle: Last 12 months

SELECT
    DATE_TRUNC('month', order_date) AS date,
    channel AS series,
    SUM(revenue) AS value
FROM read_csv_auto('orders.csv')
GROUP BY 1, 2
ORDER BY 1;
```

### Chart intents

| Intent | Use for | Produces |
|---|---|---|
| `auto` | Let asql decide | See the decision tree below |
| `trend` | A measure over time | Line chart (multi-series folds the top 8 into "Other") |
| `area` | Measure over time, filled | Same resolution as `trend`; multi-series stacks |
| `comparison` | How a few categories compare on one measure | Vertical bars (≤5 categories) / horizontal (6+), sorted by value |
| `ranking` | Where each item sits in an ordered list (top/bottom-N) | Horizontal bars, kept in your SQL's row order |
| `deviation` | Signed variance from a reference (vs plan, YoY) | Diverging bars around 0, sorted by value, green/red by sign — pass `actual - plan AS value` |
| `bullet` | Actual vs target vs qualitative bands (goal tracking) | Bar + target tick over graded bands — needs `value` + `target` columns; `bands: 60, 80, 120` |
| `slopegraph` | Before/after across many categories (two periods) | One line per category between two x positions — category + a 2-value `x` + measure |
| `bump` | Rank over time | One line per category on an inverted rank axis — category + date + measure (asql computes the rank) |
| `correlation-matrix` | Pairwise correlation across many numeric columns | Diverging heatmap of Pearson r — pass a wide result of numeric columns |
| `distribution` | Spread of **one** numeric column | Histogram (diagnostic if a categorical column is also present — use `boxplot`) |
| `boxplot` | Spread of a numeric column **across categories** | Box plot |
| `composition` | Parts of a whole | Pie (≤3 slices) / 100%-stacked bar (4+) / stacked area (if a date column is present) |
| `relationship` | Correlation between two numeric columns | Scatter plot (coloured by a `series`/`color` column or a spare categorical column) |
| `bubble` | Three numeric variables | Scatter with point size from a third measure — needs `x`, `y`, `size` (alias `AS size`); optional `series` colours |
| `sparkline` | The shape of a series at a glance | Tiny axis-less line (~48px). Ordered dimension + measure, single-series |
| `heatmap` | Measure across two categorical dimensions | Grid heatmap (sequential; `scale: diverging` for change-vs-zero data) |
| `combo` | Two measures, shared axis | Dual-axis bar+line — columns `x`, `bar`, `line`, or `@x: <col>` + two measure columns (bar then line) |
| `funnel` | Stage-by-stage drop-off | Horizontal bars — needs a `stage` column + a measure; shows step-to-step conversion |
| `waterfall` | Cumulative build-up/breakdown | Floating bars — `label` (or `dimension`) + `value`; optional `is_total` (else first/last row are the totals) |
| `flow` | Volume moving between stages/entities | Sankey diagram — edge list: `source`/`from`, `target`/`to`, numeric `value`/`metric`; dashboard only, a cycle or self-loop is a diagnostic |
| `kpi` | One headline number | Big number (1 col), tile row (2-6 cols), or table (7+) |
| `table` | Anything else / raw results | Formatted table (auto-paginated if large) |

**`auto` decision tree** — 1 row + 1–6 measures → `kpi`; else a temporal column → `trend`;
else a categorical column → `ranking`; else `table`.

**`comparison` vs `ranking`** — `comparison` answers "how do these categories compare in
magnitude?" (sorted by value). `ranking` answers "what's the order — who's #1?" and keeps
your `ORDER BY … LIMIT N` row order untouched. Both want you to sort in SQL.

**Series folding** — `trend`/`area` with more than 8 distinct series keeps the top 8 by
total and folds the rest into an "Other" band, with a footnote. Filter or aggregate in SQL
if you want different grouping.

### Column naming (so asql infers axes without overrides)

| Alias | Meaning | Example |
|---|---|---|
| `date` | Temporal axis | `order_date AS date` |
| `dimension`, `label` | Categorical axis (`dimension` checked first; `label` needed for `waterfall`) | `region AS dimension` |
| `series`, `color` | Grouping/series | `channel AS series` |
| `value`, `metric` | The measure | `SUM(revenue) AS value` |
| `x`, `y` | Explicit axes (also used by `@x`/`@y` overrides) | `x`, `y` |
| `source`, `from` | `flow` only — the edge's origin node | `region AS source` |
| `target`, `to` | `flow` only — the edge's destination node (a different `target` than `bullet`'s target measure or the `-- target:` reference line) | `segment AS target` |

Falls back to SQL types (a `DATE` column → temporal) and finally column order when these
names aren't used.

### Explicit overrides (metadata lines under `-- @chart:`)

```sql
-- @chart: trend
-- title: Revenue vs. Goal
-- @x: order_date
-- @y: revenue
-- x-format: week
-- format: dollar
-- target: 500000 | Annual Goal | #d4a017; 750000 | Stretch Goal
-- event: 2025-06-15 | Product Launch
-- facet: region
-- delta-field: pct_change
-- delta-label: vs. last month
-- delta-neutral: true
-- ma-field: revenue_ma7
-- ci: ci_low | ci_high
-- labels: true
-- height: 300px
```

| Key | Example value | Effect |
|---|---|---|
| `@x`, `@y`, `@series` | `@x: order_date` | Force which column is which — always wins over inference. |
| `x-label`, `y-label`, `series-label` | `y-label: Revenue ($)` | Relabel axes/legend. |
| `format` | `dollar`, `pct`, `kilo`, or any [d3-format](https://d3js.org/d3-format) string | Numeric axis + tooltip format. `pct`→`.0%`, `dollar`→`$,.0f`, `kilo`→`~s`. |
| `x-format` | `week`, or a [d3-time-format](https://d3js.org/d3-time-format) string like `%b %d, %Y` | `week` buckets a temporal x-axis's ticks by week. Any other value is a literal d3-time-format string applied to the rendered axis ticks. |
| `y-zero` | `false` | Y-axis starts at the data min instead of the default zero baseline, on charts whose y-axis is the numeric measure (`trend`, `area`, `scatter`, `bubble`, and a vertical `bar`). |
| `show-points` | `false` or `true` | `trend` only — `false` hides a short single-series line's point markers (normally shown when the series has ≤12 rows); `true` forces them on regardless of row count or series count (works on a multi-series line too). |
| `scale` | `diverging` | `heatmap` only — a red↔blue ramp centred at 0, for change/variance data. Default is sequential. |
| `bands` | `60, 80, 120` | `bullet` only — ascending qualitative-range thresholds shaded behind the measure bar. |
| `fit` | `true` | `relationship` only — overlay a linear regression line. |
| `facet` | `region` | Splits into small multiples, one panel per distinct value. |
| `target` | `500000 \| Annual Goal \| #d4a017; 750000 \| Stretch Goal` | Fixed reference line(s) on the quantitative axis; `;`-separated `value \| label \| color`, label/color optional. On a `kpi`, renders an attainment caption ("83% of target") instead of a line. |
| `event` | `2025-06-15 \| Product Launch` | Fixed reference line(s) on the temporal axis, same shape as `target`. |
| `annotation` | `2026-03-01 \| Price change \| #da438a` | `trend`/`area` only — floating text callout(s) at an x position, pinned to the plot top; `;`-separated `x \| text \| color`, color optional. Keeps its own data (survives filtering). |
| `segment` | `120 \| 2026-01-01 \| 2026-06-30 \| H1 avg \| #26468a` | `trend`/`area` only — partial-width horizontal reference rule(s) spanning `x-start`..`x-end` at a constant `y`; `;`-separated `y \| x-start \| x-end \| label \| color`, label/color optional, `y` must be numeric. |
| `lights` | `0.8, 0.95` | `table`/`kpi` only — exactly two ascending thresholds deriving a good/warn/bad status dot from the `value`/`metric` column when there's no explicit `status` column. See "Few-style scorecards" below. |
| `delta-field` | `pct_change` | Column with a signed delta for a `kpi` card → ▲/▼ badge (green up, red down). |
| `delta-label` | `vs. last month` | Text next to the delta badge. |
| `delta-neutral` | `true` | Always render the delta badge gray regardless of sign. |
| `ma-field` | `revenue_ma7` | Column with a pre-computed moving average, overlaid as a second line — `trend` only, single-series only. |
| `ci` | `ci_low \| ci_high` | Two columns holding a pre-computed interval (asql does no stats). On `trend`: a translucent band, one colour-matched band per series (the A/B-readout case; keep to ≤8 distinct series). On `comparison`/`ranking`: error-bar whiskers, single-series only. Any other chart type (`area` included) is an error. |
| `labels` | `true` | Show each bar's value as a text label. |
| `grouped` | `true` | Dodge a multi-series bar's segments side-by-side instead of stacking them. Silently ignored when the chart isn't a multi-series bar. |
| `show-total` | `true` | Print the summed total above each bar of a **stacked** multi-series bar. Ignored when `grouped` is also set (a dodged bar has no single stack top), or off a multi-series bar. |
| `mark-color` | `#da438a` | Hex fill for a **single-series bar / line / area / scatter** mark only. A named error on a multi-series chart (series colour scale wins) or on any chart whose colour is set by the data (pie, heatmap, deviation, stacked bar, bullet, combo, funnel, waterfall, slopegraph, bump, correlation matrix, flow). |
| `series-color` | `downside #da1e28, baseline #64748b` | Per-series colour on a **multi-series `trend`/`area`**. Comma-separated `<series value> <colour>`; colour is the last token, so multi-word names work. Unlisted series keep the palette. Silently ignored elsewhere. |
| `series-dash` | `forecast, downside dotted` | Per-series stroke on a **multi-series `trend`** (line only). Comma-separated `<series value> [dashed\|dotted]`, default `dashed`. Unlisted series stay solid. Ignored on `area` / single-series / other chart types. |
| `zoom` | `x`, `y`, `xy` | Opt in to scroll-zoom + drag-pan on a `trend`/`area`/`scatter`/`bubble` chart. Off unless set. Ignored on faceted / overlay-carrying charts and in narrative format. |
| `height` | `300px` | Override a chart/image's rendered height; width stays proportional. |

`facet`, `format`, `target`, `event`, `annotation`, `segment` aren't supported on
`combo`/`funnel`/`waterfall`, or (for `target`/`event`) on `pie`/`heatmap`/`distribution`'s
histogram — using them there produces a named error card. `annotation`/`segment` are
rejected on any non-`trend`/`area` chart. `flow` rejects `facet`/`labels`/`target`/`event`/
`annotation`/`segment` the same way, but `format` is allowed — it formats the node/link
tooltip values.

### `-- @chart: flow` — Sankey diagrams

An edge list, one row per flow: `source` (or `from`), `target` (or `to`), and a numeric
`value` (or `metric`). Node rank (column), stacking, and each link's ribbon path are
computed in V and rendered as a **raw Vega v5 spec** (not Vega-Lite — there's no
declarative Sankey mark to delegate to).

```sql
-- @chart: flow
-- title: Signups by source and outcome

SELECT source, target, value FROM acquisition_edges;
```

- **Dashboard only.** Narrative format renders a diagnostic card instead of a chart.
- **A self-loop or a cycle is a diagnostic**, not a broken chart — a Sankey's node ranking
  only has a well-defined answer on a DAG.
- Duplicate `source`/`target` pairs are summed into one link automatically.
- Never responds to `-- filter:`/`-- slider:`/`-- slider-range:` — the spec carries no
  filter signals for the control bar's JS to bind to.
- `format` formats the node/link tooltip values; `facet`, `labels`, `target`, `event`,
  `annotation`, `segment`, and `mark-color` are all rejected (see the overrides table above).

### Few-style scorecards on `table` / `kpi`

Not a new chart type — `table` and single-value `kpi` cards auto-detect a fixed set of
reserved column names (case-insensitive) and decorate the `value`/`metric` column's cell
with them, hiding the decoration columns themselves from the table's header:

| Column name | Effect |
|---|---|
| `value` or `metric` | The primary measure the other decorations attach to. Required for `status`/`target`/`delta` to have any effect on a `table`; on `kpi` this is just `@y`. |
| `spark` or `sparkline` | An array-as-text column (e.g. DuckDB `LIST` cast to text, `[1.0, 2.0, 3.0]`) → a small inline sparkline. Stays visible as its own column on `table`. |
| `status` | Text values `good`/`warn`/`bad` → a colored dot beside the value. Takes priority over `lights`. |
| `target` | A numeric column → combines with `value` into a compact bullet-in-cell (fill bar + target tick), replacing the plain number. |
| `delta` | A numeric column → a ▲/▼ badge after the value, same styling as `kpi`'s `-- delta-field:`. On `kpi`, `-- delta-field:` takes precedence if set; a bare `delta` column is used automatically otherwise. |

`target`/`delta` columns don't count toward `kpi`'s "2–6 numeric columns → tiles" auto-promotion — they're decorations on the primary value, not separate KPI measures.

A row of KPI-only cards (all `kpi`/`kpi_tiles`, no chart/table mixed in) automatically aligns
every tile's value across the row regardless of how each card's title wraps; a mixed row
leaves values at their natural top position.

## `-- @narrative` — templated prose from a one-row query

```sql
-- @narrative
-- title: Summary

SELECT SUM(revenue) AS revenue, COUNT(*) AS orders FROM orders;

-- Total revenue was {{ revenue }} across {{ orders }} orders.
```

Metadata, one SQL statement, a blank line, then the prose template as more `--`-prefixed
lines. `{{ column_name }}` substitutes a result column. Query must return exactly one row;
an unknown `{{ key }}` or a multi-row result renders as an error card. Works in either
report `format`.

## `-- @markdown` — static prose, no query

```sql
-- @markdown
-- title: Methodology

-- We define active users as anyone with **at least one** session in the trailing 28 days.
-- - Excludes internal/test accounts
-- - Timezone: UTC
```

The body is written as `--`-prefixed comment lines (blank lines as a bare `--`), same as
a `@narrative` template — asql strips the `-- ` and renders the rest as Markdown, and the
file stays valid SQL. A bare-text (uncommented) body breaks parsing.

### Math

`@markdown` bodies and `@narrative` prose support TeX math via KaTeX: `$…$` inline
(`$E = mc^2$`), `$$…$$` display (`$$\sum_{i=1}^{n} x_i$$`). Recognised only in those prose
contexts. Currency like `$5` is always safe — asql renders inline `$…$` math as `\(…\)`
internally, so a bare `$` is never a math delimiter.

## `-- @image` — embed a local image file

```sql
-- @image
-- title: Architecture
-- path: diagrams/pipeline.png
-- caption: Data pipeline overview
-- height: 400px
```

| Key | Required? | Effect |
|---|---|---|
| `path` | yes | Resolved relative to the report file's own directory, embedded as a base64 data URI. `src` is an accepted alias. |
| `caption` | no | Caption text under the image. |
| `height` | no | Override rendered height; width stays proportional. |

A missing/unreadable file renders as an error card.

## Data sources

Anything DuckDB can read directly, no ingestion step:

```sql
FROM 'data/sales.parquet'
FROM read_csv_auto('data/orders.csv')
FROM 'warehouse.duckdb'.main.orders
```

## Theming

```css
:root {
  --accent: #26468A;         /* shell: headings, links, section rules, KPI borders */
  --chart-accent: #26468A;   /* single-series charts + heatmap ramp high end */
  --chart-palette: #26468a, #8a489e, #da438a, #ff6559, #ffa600, #6f8fd0, #c194d4, #f292c0, #ff9e86, #ffce7a;
}
```

`--theme <file>.css` layers a CSS file over the default stylesheet — flag goes before the
report path. Override any shell property: `--canvas`, `--paper`, `--ink`, `--ink-soft`,
`--line`, `--accent`, `--accent-soft`, `--positive`, `--negative`, `--sans`, `--mono`.

Charts inherit the shell (`--ink`, `--line`, `--paper`, `--positive`, `--negative` drive
chart text, gridlines, plot background and up/down colors), so restyling the shell restyles
the charts. Chart-specific overrides win when you need them to differ — each resolves
chart-specific → shell property → built-in default, independently:

- `--chart-accent` — single-series marks; `--chart-palette` — multi-series, a comma-separated
  hex list of **any length** (the built-in default is the 10 colors above)
- `--chart-ink`, `--chart-ink-soft`, `--chart-grid`, `--chart-background`
- `--chart-positive`, `--chart-negative`, `--chart-neutral`
- `--chart-diverging-lo`, `--chart-diverging-hi`, `--chart-sequential-hi`

Ready-made themes ship under `themes/`: `midnight`, `sepia`, `nordic`, `forest`, `mono` —
each defines a `--chart-palette`; copy one and tweak it.

## Viewing a built report (dashboard format)

Every chart card has a small "..." button next to its title (dashboard format only —
narrative format is static SVG) letting a viewer save that chart as PNG or SVG, no export
step needed from the report author.

## Error handling

A broken block (bad SQL, an intent/data-shape mismatch, an unknown `{{ key }}`) renders as
a red diagnostic card in place, naming what was detected — it never breaks the rest of the
report. Always check for these after building; the build itself still "succeeds."
