# asql Tutorial

`asql` turns a `.sql` file annotated with lightweight `-- @` comments into a polished,
self-contained HTML analytics report. You write SQL. `asql` figures out the chart.

## Install

See `README.md`'s **Install** section — `curl | sh`, a manual tarball, or Docker.
Everywhere below, `asql` means whichever binary/launcher that gave you (in Docker,
substitute `docker run --rm -v "$PWD:/work" ghcr.io/cuiqanalytics/asql` for `asql`).

## Your first report

Create `revenue.sql` (this uses inline `VALUES` so it runs with no data file of its
own — point `read_csv_auto` at a real file once you have one):

```sql
-- @report
-- title: Revenue Dashboard
-- subtitle: 2026

-- @setup
CREATE OR REPLACE VIEW orders AS (
    SELECT * FROM (VALUES
        ('2026-01-03'::DATE, 'organic', 1200, 'Austin'),
        ('2026-01-14'::DATE, 'paid',     900, 'Denver'),
        ('2026-02-02'::DATE, 'organic', 1450, 'Austin'),
        ('2026-02-19'::DATE, 'referral', 700, 'Seattle'),
        ('2026-03-05'::DATE, 'paid',    1100, 'Denver'),
        ('2026-03-21'::DATE, 'organic', 1600, 'Austin')
    ) AS t(order_date, acquisition_channel, revenue, city)
);

-- @chart: trend
-- title: Revenue Trend

SELECT
    DATE_TRUNC('month', order_date) AS date,
    acquisition_channel AS series,
    SUM(revenue) AS value
FROM orders
GROUP BY 1, 2
ORDER BY 1;


-- @chart: ranking
-- title: Top Cities

SELECT
    city AS dimension,
    SUM(revenue) AS value
FROM orders
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;


-- @chart: kpi
-- title: Total Revenue

SELECT
    SUM(revenue) AS value
FROM orders;
```

Build it:

```bash
asql build revenue.sql
```

This writes `revenue.html` next to the source file — a self-contained page with a
multi-series line chart, a horizontal bar chart, and a KPI card. Open it in a browser. No
server needed.

You didn't specify chart types, axes, or series groupings anywhere. `asql` inferred all
of it from the intents (`trend`, `ranking`, `kpi`) and the SQL result shape.

## Live preview while you edit

```bash
asql preview --port 4321 revenue.sql
```

(Note the flag comes *before* the file — `asql preview revenue.sql --port 4321` silently
falls back to the default port instead of erroring, a quirk of V's CLI flag parser.)

Open `http://localhost:4321`. Every time you save `revenue.sql`, the open tab
automatically rebuilds and reloads — no manual `asql build`, no page refresh. If the file
is briefly unparseable mid-edit, the page shows the error instead of crashing, and
recovers on your next save.

### Editing a block in the browser

Every card in the preview has a small "✎ Edit" link in its top-right corner. Click it to
open an overlay for just that block — the rest of the dashboard stays visible and scrolled
where it was underneath, so you never lose your place navigating away and back.

The overlay's fields depend on the block's kind: `@chart` gets a Chart Type dropdown (every
intent from the table above, saved immediately on selection — no more hand-editing the
`-- @chart: <intent>` header line to try a different chart) plus Metadata + SQL,
`@narrative` gets Metadata + SQL + Template (the `{{ column }}`-templated prose sentence),
`@markdown` gets Metadata + Content (relabeled — it's prose, not SQL), and `@image` gets
Metadata only, since `path`/`caption`/`height` are already plain metadata lines with
nothing else to edit. The SQL field is a real syntax-highlighted editor (CodeMirror); a
failed run tries to mark the offending line in the gutter when DuckDB's error message
includes one, alongside the full message in a banner.

Typing in any field auto-saves after a short pause (debounced, so it doesn't write on
every keystroke) — a status indicator next to "✕ Close" tracks this ("Editing…" →
"Saving…" → "Saved", or "Save failed" if something goes wrong). Metadata/Template edits
rebuild the card without re-running SQL; to re-run the query itself, click "Run ▶" (or
press Ctrl/Cmd+Enter). A "Revert" button resets every field back to what it was when you
opened the overlay — a single undo step for this editing session, not a full history — and
a "? Help" toggle shows a quick reference for chart intents and every metadata override key
(not filtered to the current block's specific kind).

Close with "✕ Close", Escape, or by clicking outside the overlay. There's no "Export"
button in preview anymore — you're already at a terminal running `asql preview`, so
`asql build revenue.sql` is one command away and does the exact same thing.

The report title and any `-- @section:` heading also get their own "✎ Edit" — same
autosave/Revert/Help pattern, just a single metadata field instead of the full overlay.

## Running a query without the report pipeline

```bash
asql query revenue.sql
asql query --format csv revenue.sql
```

`asql query` runs a flat `.sql` file straight through DuckDB and prints the result as a
plain text table (or CSV with `--format csv`). It does **not** parse `-- @` annotations at
all — `-- @` lines (including `-- @setup`) are just SQL comments and are ignored. DuckDB
runs every statement in the file and you get back only the **last** statement's rows, not
all of them. Duplicate output column names collapse (a pre-existing `exec` limitation) —
alias them distinctly. Point it at a scratch `.sql` or a self-contained query.

## The file format

A report is a sequence of blocks. Each block starts at a line matching `-- @<type>` and
runs to the next such line or end of file.

### `-- @report`

Report-level metadata only — no SQL.

```sql
-- @report
-- title: My Report
-- subtitle: June 2026
-- layout: grid_2x2
-- description: Optional longer description
-- author: Analytics Team
```

`layout` is `single` (default) or `grid_2x2`/`grid_3x2` — a CSS grid with that many
columns. It applies to the report as a whole when you don't use `-- @section:` (see
below); with named sections, each section sets its own `layout` instead.

Report chrome — shown in the page header if set: `brand`, `team`, `date-range`,
`experiment-id`, `generated-date`, `dataset-version`, `max-width`.

`refreshed-at` renders a floating "Updated `<value>`" badge (dashboard format only).
Give it a plain string (`-- refreshed-at: Jun 30, 2026`), or a SQL scalar expression
with a leading `= ` that is evaluated at build time — `-- refreshed-at: = CURRENT_TIMESTAMP`
(or `= MAX(order_date) FROM some_view`, with the view defined in `-- @setup`). A failed
expression degrades to `unavailable`; it never breaks the build.

```sql
-- @report
-- title: Q2 Growth Experiment
-- brand: Acme Analytics
-- date-range: Apr 1 - Jun 30, 2026
-- experiment-id: EXP-1042
```

Set `-- toc: true` to add a table of contents built from every labeled `-- @section:` —
sections with no label, or `label_visible: false`, are skipped since there's nothing to
link to. It renders differently per format: `dashboard` gets a floating sidebar on the
left (wide viewports only — it hides rather than overlap the content column on a narrower
one), `narrative` gets an inline block right after the masthead, in the normal reading
flow. Either way it's just clickable jump-links, no active-section highlighting as you
scroll.

```sql
-- @report
-- title: Q2 Growth Experiment
-- toc: true

-- @section: overview
-- label: Overview
...
```

### `-- filter: <column>` — interactive filters

Add `-- filter: region` to `-- @report` and asql renders a sticky control bar above the
report with a `region` dropdown (All + every distinct value found across the charts).
Changing it re-filters every chart live in the browser — no rebuild, no server.

```sql
-- @report
-- title: Sales
-- filter: region

-- @chart: trend
-- @series: region
SELECT month AS date, region, revenue AS value FROM sales;

-- @chart: ranking
SELECT region, SUM(revenue) AS value FROM sales GROUP BY region;
```

Rules:

- **Each participating chart's `SELECT` must project the filter column** — either under its
  own name, or aliased the usual way to make it the chart's series (`region AS series`).
  asql matches `-- filter: region` against the result column name *and* against a plain
  `region AS <alias>` in the query. A chart that doesn't project the column at all — or only
  computes it (`CASE … END AS region`, or it lives in a subquery) — is left alone and just
  won't respond to that dropdown.
- KPIs, tables, and the `funnel` / `waterfall` / `bump` / `correlation-matrix` intents
  never filter, even if they select the column. The bar's note reads "filters charts only".
  `flow` never filters either — it's a raw Vega spec with no `-- filter:`/`-- slider:`
  signal wiring at all.
- Multiple columns: `-- filter: region; channel` (separate with `;` or `,`) gives one
  dropdown each; they combine (AND).
- The selection is written to the URL as `#region=East&channel=paid`, so a filtered view
  is a shareable link — open that URL and the dropdowns restore themselves before the
  charts render.
- Legend-click isolation (click a series in the legend to solo it) is automatic on every
  multi-series chart, independent of `-- filter:`.
- `-- filter-exclusive: region` drops the "All" option from that column's dropdown,
  forcing the browser's default first value — use it when "All" would never make sense for
  that column. Same `;`/`,`-separated list shape as `filter`; a column must also be listed
  in `filter` to have any effect.

### `-- slider:` / `-- slider-range:` — the same filter bar, as sliders

`-- slider: region` renders the identical control as a discrete slider (drag or arrow keys
through All + every distinct value) instead of a dropdown — same participation rules, same
`flt_region` signal, same URL-hash sync as `-- filter:` above. Pick it when there's a
handful of ordered values and stepping through beats scanning a dropdown.

`-- slider-range: deal_size` renders a min/max range slider (two thumbs) over a numeric
column instead — it writes one `"min..max"` signal, and the participating chart's filter
becomes a numeric range check rather than an equality check:

```sql
-- @report
-- title: Deals
-- slider-range: deal_size

-- @chart: boxplot
SELECT segment AS dimension, deal_size AS value FROM accounts;
```

The URL hash carries the range as `#deal_size=300..12000`. A column can be in `filter`,
`slider`, or `slider-range` — never more than one of the three.

### Zoom & pan

Add `-- zoom:` to a `trend`, `area`, `scatter`, or `bubble` chart to make it zoomable in
the dashboard format — scroll to zoom, drag to pan, double-click to reset. Off unless you
ask for it.

```sql
-- @chart: trend
-- zoom: xy       -- both axes

-- @chart: trend
-- zoom: x        -- only the time axis
```

`-- zoom:` is ignored on faceted charts and on charts that carry an overlay (a reference
line, CI band, moving average, or annotation) — a scale-bound interaction on those doesn't
render cleanly. Narrative format ignores it too (its charts are static).

### `-- @setup`

Every block's query runs as its own independent SQL statement — normally that means
repeating the same prep work (a CTE, a staging table) in every block that needs it. A
`-- @setup` block, placed right after `-- @report`, runs once before whatever block query
actually needs it and lets you define that prep work a single time:

```sql
-- @report
-- title: Revenue Dashboard

-- @setup
CREATE OR REPLACE VIEW orders AS (
    SELECT * FROM read_csv_auto('orders.csv') WHERE status != 'cancelled'
);

-- @chart: trend
-- title: Revenue Trend

SELECT DATE_TRUNC('month', order_date) AS date, SUM(revenue) AS value FROM orders GROUP BY 1;
```

It's plain SQL, no metadata lines, no card of its own — it never appears in the report.
Multiple `-- @setup` blocks are allowed and run in document order if you want to split
setup into a few logical pieces. Use `CREATE OR REPLACE` rather than plain `CREATE`: this
SQL actually runs again before *every* block's query, not once for the whole report — a
full build shares one DuckDB connection across all blocks, but each preview-mode block
editor opens its own fresh, isolated connection per request, so it needs to see the same
setup again to have anything to reference. `CREATE OR REPLACE VIEW`/`TABLE` make that
re-run a no-op rather than an error.

### `-- @section: <name>`

Splits the report into independently laid-out sections. Each section gets its own grid:

```sql
-- @section: overview
-- label: Overview
-- layout: two-col
-- collapsible: true

-- @chart: trend
...

-- @section: detail
-- label: Detail
-- layout: grid_3x2

-- @chart: ranking
...
```

`layout` per section is one of `single`, `full`, `grid_2x2`/`two-col`,
`grid_3x2`/`three-col`, `kpi-grid`, `sidebar-main`, `hero`, `tabs`. `label` is the
heading shown above the section. `collapsible: true` renders it as a `<details>` you can
collapse. If you never write `-- @section:`, all blocks land in one implicit section that
uses the report-level `layout`.

`layout: tabs` on a section with more than one card renders the cards as tabs, one per
card, with the tab label taken from each card's title. A `tabs` section with a single
card falls back to the normal single-column layout. Charts on a tab that isn't open yet
render the first time you switch to it. Narrative format ignores `tabs` — it is a
dashboard-only affordance.

### `-- @markdown`

Static prose — no SQL. Metadata lines, a blank line, then the body written as
`--`-prefixed comment lines (blank lines in the body are a bare `--`). asql strips the
`-- ` prefix and renders the rest as Markdown.

```sql
-- @markdown
-- title: Methodology

-- We define an **active user** as anyone with at least one session in the trailing
-- 28 days.
--
-- - Excludes internal and test accounts
-- - All timestamps are UTC
```

The body must be commented, not written as bare Markdown — same rule as `@narrative`'s
template, and for the same reason: the whole file stays valid, runnable SQL
(`cat report.sql | duckdb` still works). A bare-text body breaks parsing — the first
blank line ends the block's metadata phase, and anything after it that isn't a `--`
comment falls outside the block entirely.

### `-- @chart: <intent>`

Metadata lines (`-- key: value`), then exactly one SQL statement running to the end of
the block.

```sql
-- @chart: trend
-- title: Monthly Revenue
-- subtitle: Last 12 months

SELECT ...
```

### `-- @narrative`

Same shape as `@chart`, but after the SQL statement there's a blank line, then the prose
template — written as `--`-prefixed comment lines, same as any other metadata — that can
reference the query's result with `{{ column_name }}`:

```sql
-- @narrative
-- title: Summary

SELECT SUM(revenue) AS revenue, COUNT(*) AS orders FROM orders;

-- Total revenue was {{ revenue }} across {{ orders }} orders.
```

Keeping the template inside `--` comments (rather than bare text) means the whole file
stays valid, runnable SQL on its own — `cat report.sql | duckdb` works even on a report
with narrative blocks, since nothing outside a comment is anything other than SQL.

The query must return exactly one row. An unknown `{{ key }}` (or a query that doesn't
return exactly one row) renders as an error card instead of breaking the whole report —
same as every other block-level failure.

### Math

Prose in `@markdown` bodies and `@narrative` templates can carry TeX math, rendered
client-side by KaTeX: `$…$` for inline math (`$E = mc^2$`) and `$$…$$` for a centred
display block (`$$\sum_{i=1}^{n} x_i$$`). Math delimiters are only recognised in those
two prose contexts — never in titles, SQL, or chart labels.

Currency like `$5` is always safe — asql renders inline `$…$` math as `\(…\)` internally,
so a bare `$` is never a math delimiter.

## Chart intents

Put one of these after `-- @chart:`. `asql` picks the mark, axes, and series from your
SQL's column names and types — you only override what inference gets wrong.

| Intent | What it's for | Result |
|---|---|---|
| `auto` | Let the engine decide | KPI for a single summary row, a line for a temporal result, a bar for a categorical one, else a table |
| `trend` | A measure over time | Line chart. Multiple series fold into "Other" past the top 8 by total value |
| `area` | A measure over time, area-filled | Same resolution as `trend`, rendered as an area mark |
| `comparison` | How a few categories compare on one measure (magnitude) | Vertical bars (≤5 categories) or horizontal bars (6+), sorted by value |
| `ranking` | Where each item sits in an ordered list — who's #1? | Always horizontal bars, kept in your SQL's row order (so your own `ORDER BY`/`LIMIT` controls it) |
| `deviation` | Signed variance from a reference point (actual vs plan, year-on-year change) | Diverging horizontal bars around a zero baseline, sorted by signed value, coloured green (above) / red (below). Supply the signed number as the measure: `actual - plan AS value` |
| `bullet` | An actual measure against a target and qualitative ranges (goal / OKR tracking) | Stephen Few bullet graph: a measure bar and a target tick over graded background bands. Needs a `value` and a `target` column; set the ranges with `bands: 60, 80, 120` |
| `slopegraph` | Before/after across many categories (two time points) — level *and* rank change | One line per category between two x positions. Needs a category dimension, an `x` column with two values, and a measure |
| `bump` | Rank over time (racing positions) | One line per category on an inverted rank axis. Needs a category dimension, a date, and a measure — asql computes the rank per period |
| `correlation-matrix` | Which of many numeric variables move together | Diverging heatmap of pairwise Pearson r. Pass a wide result of numeric columns; asql computes the matrix |
| `distribution` | Spread of **one** numeric column | Histogram. A categorical column also present is a diagnostic — use `boxplot` to compare spread across groups |
| `boxplot` | Spread of a numeric column **across categories** | Box plot, grouped by a categorical dimension |
| `composition` | Parts of a whole | Pie (≤3 slices), a single 100%-stacked bar (4+ categories), or a stacked area chart if a date column is present |
| `relationship` | Correlation between two numeric columns | Scatter plot, coloured by a `series`/`color` column (or a spare categorical column) if present |
| `bubble` | Three numeric variables at once | Scatter with point size driven by a third measure. Needs `x`, `y`, and a `size` column (alias one `AS size`); optional `series` colours the points |
| `sparkline` | The shape of a series, in a glance | A tiny axis-less line, ~48px tall. Needs an ordered dimension + a measure; single-series only |
| `heatmap` | A measure across two categorical dimensions | Grid heatmap (sequential colour; set `scale: diverging` for change-vs-zero data); requires two categorical columns plus a numeric measure |
| `combo` | Two measures over a shared axis | Dual-axis bar+line; requires columns literally named `x`, `bar`, `line` |
| `funnel` | Stage-by-stage drop-off | Horizontal bars sized by % of first stage; needs a categorical stage column (alias `stage`) and a numeric measure |
| `waterfall` | Cumulative build-up/breakdown | Floating bars from running totals; requires columns literally named `label`, `value`, `is_total` |
| `flow` | Volume moving between stages/entities | Sankey diagram; edge list requires `source`/`from`, `target`/`to`, and a numeric `value`/`metric` — dashboard only, a cycle or self-loop is a diagnostic |
| `kpi` | One headline number | A single big number (1 numeric column), a tile row (2–6 columns), or a table (7+) — query must return exactly 1 row |
| `table` | Anything else | Raw result as a formatted table |

**`comparison` vs `ranking`.** `comparison` answers "how do these categories compare in
size?" and sorts by value. `ranking` answers "what is the order?" and leaves your row order
alone. Sort in SQL either way.

**Series folding.** `trend` and `area` with more than 8 distinct series keep the 8 largest
by total and fold the rest into a single "Other" band (with a footnote). Aggregate or
filter in SQL if you want a different grouping.

## Column naming conventions

Name your `SELECT` columns using these aliases and `asql` will map them automatically:

| Alias | Meaning |
|---|---|
| `date` | Temporal axis |
| `dimension`, `label` | Categorical axis |
| `series`, `color` | Grouping/series |
| `value`, `metric` | The measure |
| `x`, `y` | Explicit axes (used by `relationship`, or as overrides) |

If you don't use these names, `asql` falls back to inferring from SQL types (a `DATE`
column becomes temporal, a numeric column with more than 50 distinct values — and more
than 20% of the row count — becomes a measure rather than a category) and finally to
plain column order.

## Explicit overrides

When inference gets it wrong, override it per block:

```sql
-- @chart: trend
-- @x: order_month
-- @y: revenue

SELECT order_month, revenue FROM monthly_summary;
```

`@x`, `@y`, and `@series` always win over automatic inference. A typo'd column name here
produces an error card telling you what columns are actually available, rather than
silently rendering a blank chart.

Every chart also gets a tooltip automatically (hover a point/bar/slice to see its field
values). To relabel axes/legend or apply a number format instead of the raw column name,
add any of these (no `@`, same as `title`/`subtitle`):

```sql
-- @chart: trend
-- x-label: Month
-- y-label: Revenue ($)
-- series-label: Channel
-- format: $,.0f

SELECT order_month, revenue, channel FROM monthly_summary;
```

`format` is a [d3-format](https://d3js.org/d3-format) string applied to whichever axis is
numeric (and to that field's tooltip entry). Three named shortcuts are also accepted in
place of a raw d3-format string: `pct` (`.0%`), `dollar` (`$,.0f`), `kilo` (`~s`).

For a temporal x-axis, `-- x-format: week` buckets ticks by week instead of the default
resolution:

```sql
-- @chart: trend
-- x-format: week

SELECT order_date, revenue FROM orders;
```

To split one chart into small multiples, add `-- facet: <column>` naming a categorical
column — one panel is drawn per distinct value:

```sql
-- @chart: trend
-- facet: region

SELECT order_month, revenue, region FROM monthly_summary;
```

`facet` and `format` aren't supported on `combo`, `funnel`, or `waterfall` (they build a
different spec shape); using either there produces an error card naming the chart type.
`flow` rejects `facet` too, but allows `format` (it formats the node/link tooltip values).

To draw a fixed reference line (a target threshold, a launch-date marker) on a chart, add
`-- target:` and/or `-- event:`:

```sql
-- @chart: trend
-- target: 500000 | Annual Goal | #d4a017; 750000 | Stretch Goal
-- event: 2025-06-15 | Product Launch

SELECT order_date, revenue FROM orders;
```

Both accept a `;`-separated list of `value | label | color` entries — `label` and `color`
are optional (leave a middle field empty, `500000 | | #d4a017`, to set color without a
label). `target`'s value is a number compared against whichever axis is quantitative;
`event`'s value is a date/timestamp compared against whichever axis is temporal — the line
draws horizontal or vertical depending on the chart's own axis layout, not something you
specify directly. `target` and `event` aren't supported on `combo`, `funnel`, `waterfall`,
or `flow` (same restriction as `facet`/`format`, `flow` excepted), or on
`pie`/`heatmap`/`distribution`'s histogram, which have no comparable value/temporal axis.

On a `trend` or `area` chart you can also add floating callouts:

```sql
-- @chart: trend
-- annotation: 2026-03-01 | Price change | #da438a
-- segment: 120 | 2026-01-01 | 2026-06-30 | H1 avg | #26468a

SELECT week, mrr FROM revenue;
```

`annotation` places a text label at an x position (`x | text | color`, `;`-separated,
color optional) pinned to the top of the plot — use it to mark an event. `segment` draws a
partial-width horizontal reference rule spanning only `x-start`..`x-end` at a constant
y value (`y | x-start | x-end | label | color`, `;`-separated; `label` and `color`
optional; `y` must be a number) — use it for a period average or a bounded threshold.
Both are `trend`/`area` only. A callout keeps its own data, so it stays put when the
chart is filtered.

A `kpi` tile can show a ▲/▼ delta alongside its value:

```sql
-- @chart: kpi
-- delta-field: change
-- delta-label: vs last month

SELECT revenue AS value, revenue - prior_revenue AS change FROM summary;
```

`delta-field` names a column holding the signed delta (positive → green ▲, negative → red
▼); `delta-label` is optional text shown next to it; `delta-neutral: true` always renders
gray regardless of sign. For a multi-tile `kpi` card (2-6 measure columns), the same
delta applies to every tile.

### Few-style scorecards on `table` / `kpi`

Not a new chart type — `table` and single-value `kpi` cards auto-detect a fixed set of
reserved column names (case-insensitive) and decorate the `value`/`metric` column's cell
with them, hiding the decoration columns from the table's header:

```sql
-- @chart: table
-- lights: 100, 115

SELECT segment AS dimension, latest_nrr AS value, 100 AS target,
    nrr_change AS delta, nrr_history AS spark
FROM segment_summary;
```

- `spark`/`sparkline` — an array-as-text column (e.g. a DuckDB `LIST` cast to text,
  `[1.0, 2.0, 3.0]`) renders as a small inline sparkline. Stays visible as its own column.
- `status` — text values `good`/`warn`/`bad` render a colored dot beside the value. Takes
  priority over `lights`.
- `target` — a numeric column combines with `value` into a compact bullet-in-cell (fill bar
  + target tick), replacing the plain number.
- `delta` — a numeric column renders a ▲/▼ badge after the value, styled like `kpi`'s
  `delta-field`. On `kpi`, `delta-field` wins if set; a bare `delta` column is used
  automatically otherwise.
- `-- lights: 0.8, 0.95` derives the `status` dot from `value`/`metric` when there's no
  explicit `status` column — two ascending thresholds, `table`/`kpi` only.

`target`/`delta` columns don't count toward `kpi`'s "2-6 numeric columns → tiles"
auto-promotion — they decorate the primary value rather than being separate measures.

### Confidence intervals — `-- ci:`

`-- ci:` takes two column names, `lower | upper`, holding a pre-computed interval. asql
does no statistics — your SQL supplies the bounds.

```sql
-- @chart: trend
-- series: arm
-- ci: ci_low | ci_high

SELECT week AS date, arm, mean_metric AS value, ci_low, ci_high FROM weekly_metric;
```

On a `trend` chart this draws a translucent band between the bounds. With a
`series` grouping you get one colour-matched band per series — the A/B-test readout, where
you eyeball whether the treatment and control intervals overlap. Keep `ci:` to ≤8 distinct
series: beyond that, the tail series fold into an `Other` bucket whose band renders as a
messy self-intersecting shape.

On a `comparison` or `ranking` chart `ci` instead draws error-bar whiskers on each bar, and
is single-series only — a `series` grouping there is an error.

### Grouped bars, stack totals, single-series colour — `grouped:` / `show-total:` / `mark-color:`

A multi-series `comparison` bar stacks its segments by default. `-- grouped: true` dodges
them side-by-side instead — better for comparing the segments to each other rather than
reading the total. `-- show-total: true` goes the other way: it keeps the stack and prints
each bar's summed total just above it. The two are mutually exclusive — a dodged bar has no
single stack top, so `show-total` is ignored when `grouped` is also set. Both silently
no-op on any chart that isn't a multi-series bar (like `target:` on a pie).

```sql
-- @chart: comparison
-- grouped: true

SELECT quarter AS dimension, channel AS series, SUM(revenue) AS value FROM sales GROUP BY 1, 2;
```

`-- mark-color: #da438a` overrides the fill of a **single-series bar / line / area / scatter**
mark only. It has no effect on a multi-series chart (the series colour scale owns every
mark's colour) or on a chart whose colour is set by the data — a pie, heatmap, deviation,
stacked bar, bullet, combo, funnel, waterfall, slopegraph, bump or correlation matrix.
Setting it on any of those is a named error rather than a silent drop.

### Per-series colour and line style — `series-color:` / `series-dash:`

On a **multi-series `trend` or `area`** chart, override individual series:

```sql
-- @chart: trend
-- series: scenario
-- series-color: baseline #64748b, aggressive #26468a, downside #da1e28
-- series-dash:  downside, aggressive dotted

SELECT month AS date, scenario AS series, value FROM forecast;
```

`series-color:` is a comma-separated list of `<series value> <colour>` entries. The colour
is the last token (a hex code or single-word CSS colour name); everything before it is the
series name, so `New York #26468a` works. Series you don't name keep their palette colour.

`series-dash:` is a comma-separated list of `<series value> [dashed|dotted]` entries —
`dashed` is the default if no style is given. Named series render with that stroke; the
rest stay solid. `series-dash` is **line only** (a dashed area outline reads badly); it is
ignored on `area`. Both directives are silently ignored on a single-series chart or any
chart type other than `trend`/`area`.

### Y-axis baseline and point markers — `y-zero:` / `show-points:`

`-- y-zero: false` drops the forced zero baseline on a chart whose y-axis is the numeric
measure (`trend`, `area`, `scatter`, `bubble`, a vertical `bar`) — the axis starts at the
data's own minimum instead, which reads better when the series stays in a narrow band far
from zero (a retention percentage hovering around 100%, say).

```sql
-- @chart: trend
-- y-zero: false

SELECT month AS date, nrr AS value FROM segment_month;
```

`-- show-points:` controls a `trend` line's point markers. They render automatically on a
short (≤12-row) single-series line and stay off otherwise; `show-points: false` hides them
on that short line, and `show-points: true` forces them on regardless of row count or
series count (including a multi-series line).

## Theming

`asql build`/`asql preview` accept `--theme <file>`, pointing at a CSS file whose rules
override the report's default stylesheet:

```bash
asql build --theme themes/midnight.css revenue.sql
asql preview --theme themes/sepia.css revenue.sql
```

(Same flag-before-file rule as `--port`/`--fresh` above.) Five ready-to-use themes ship in
`themes/`: `midnight` (dark), `sepia` (warm/print-like), `nordic` (cool blue-gray),
`forest` (earthy green), `mono` (grayscale, minimal). Point `--theme` at any of them, or
write your own.

### Chrome colors and fonts

A theme file just needs a `:root` block redefining any of the CSS custom properties the
default stylesheet already uses — everything (backgrounds, cards, tables, KPI tiles)
cascades from these:

```css
:root {
  --canvas: #0F1115;      /* page background */
  --paper: #1A1D23;       /* card/table background */
  --ink: #E8E9ED;         /* primary text */
  --ink-soft: #9CA3AF;    /* secondary text */
  --line: #2D3139;        /* borders/rules */
  --accent: #7C9EFF;      /* headings, links, section-label rules */
  --accent-soft: #1E2A4A; /* accent-tinted backgrounds (row hover, etc.) */
  --positive: #4ADE80;    /* KPI up-deltas */
  --negative: #F87171;    /* KPI down-deltas */
  --sans: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
  --mono: ui-monospace, 'SF Mono', Consolas, monospace;
}
```

Beyond variables, a theme file can override any selector directly (see the shipped themes
for examples: `sepia.css`/`forest.css` switch to a serif and drop the underline beneath
section titles; `mono.css` squares off every corner and strips shadows/borders).

Both formats default to the OS system sans (Segoe UI on Windows, San Francisco on macOS,
etc.) with no webfonts, so a report looks native wherever it's opened. Dashboard format's
typography is entirely `--sans`/`--mono`-driven; narrative format ships its own stylesheet
and ignores a theme file's font variables — restyle it by targeting `body`, `h1`,
`h2.section-label`, etc. directly instead.

### Chart colors

Charts (both dashboard's Vega-Lite charts and narrative's static SVG charts) inherit
the report shell's own custom properties: `--ink`, `--ink-soft`, `--line`, `--paper`,
`--positive` and `--negative` drive chart text, tick labels, gridlines, plot background
and semantic up/down colors whenever the chart-specific override below isn't set. So a
theme that redefines the chrome variables already restyles the charts to match.

The chart-specific overrides take precedence when you need the charts to differ from the
shell:

```css
:root {
  --chart-accent: #7C9EFF;   /* single-series charts (a plain trend/ranking/kpi chart) */
  --chart-palette: #7C9EFF, #5EEAD4, #C4B5FD, #FCA5A5;  /* multi-series; comma-separated, any length */
  --chart-ink: #E8E9ED;          /* chart text/labels */
  --chart-ink-soft: #9CA3AF;     /* axis titles, tick labels */
  --chart-grid: #2D3139;         /* gridlines */
  --chart-background: #1A1D23;   /* plot background */
  --chart-positive: #4ADE80;     /* up bars, waterfall increases */
  --chart-negative: #F87171;     /* down bars, waterfall decreases */
  --chart-neutral: #9CA3AF;      /* waterfall totals */
  --chart-diverging-lo: #F87171; /* diverging scale low end (defaults to --negative) */
  --chart-diverging-hi: #7C9EFF; /* diverging scale high end (defaults to the accent) */
  --chart-sequential-hi: #7C9EFF;/* sequential heatmap high end (defaults to the accent) */
}
```

Each token resolves independently: chart-specific override → shell property → built-in
default. Setting only `--ink` therefore leaves tick labels at the default `--ink-soft`
unless you also set that (or `--chart-ink-soft`).

`--chart-palette` replaces asql's built-in categorical set (a 10-colour blue-to-amber
house palette). Give it as many or as few colours as you like; a chart with more series
than colours cycles back to the start, and asql already folds anything past the top 8
series into an "Other" bucket. To change the palette for *every* un-themed report instead
of per-report, edit `default_chart_category` in `src/visualization/palette.v` and rebuild.

Quantitative axes use SI abbreviation by default (`35M`, `400m`) — on a chart of
fractional values add `-- format: pct` (or any d3-format string) so `0.4` renders as
`40%`, not `400m`.

## Data sources

Anything DuckDB can read directly — local or remote, no ingestion step:

```sql
FROM 'data/sales.parquet'
FROM read_csv_auto('data/orders.csv')
FROM read_csv_auto('https://example.com/exports/orders.csv')   -- remote, over HTTPS
```

To read another DuckDB database, attach it in `-- @setup` and query the alias:

```sql
-- @setup
ATTACH IF NOT EXISTS 'warehouse.duckdb' AS wh (READ_ONLY);

-- @chart: trend
SELECT month, revenue FROM wh.orders;
```

### Community extensions

DuckDB's `INSTALL`/`LOAD` also just work in `-- @setup` — asql passes that SQL straight
through, so any [community extension](https://duckdb.org/community_extensions/list_of_extensions)
is available the same way `httpfs` is. This needs network access at *build* time only
(the extension itself, and whatever it then reads); the finished HTML report has no
DuckDB in it and stays fully offline to view, same as ever.

A few worth knowing about:

```sql
-- @setup
INSTALL rusty_sheet; LOAD rusty_sheet;    -- read .xlsx/.ods straight into a report

-- @chart: trend
SELECT * FROM read_xlsx('data/orders.xlsx');
```

- `rusty_sheet` — reads Excel/ODS/WPS files directly, no export-to-CSV step.
- `duck_diff` — diffs two relations by primary key (identical/changed/added/removed +
  per-column deltas); a natural source query for a `deviation` chart or a
  "what changed since last snapshot" table.
- `finetype` — semantic type detection (dates, currencies, emails, etc. from raw
  strings) — useful for cleaning up messy source columns before asql's own
  column-name-driven axis inference sees them.
- `datasketches` — approximate distinct counts and quantile sketches, for `kpi`/
  `distribution` charts over data too large for exact `COUNT(DISTINCT)`.
- `stats_duck` — OLS regression, hypothesis tests, and SAS/SPSS/Stata file readers;
  useful for `experiment_readout`-style reports needing real significance testing
  behind a `ci` chart, not just descriptive bands.

## Error handling

A broken block (bad SQL, a chart intent that doesn't fit the data, a narrative with an
unknown key) never breaks the rest of the report — it renders as a red diagnostic card in
place, with a message that tells you what was detected and what to try instead. Every
other block on the page still builds normally.

## Examples

Four reports in `examples/`, all on one shared synthetic "Northwind Cloud" dataset.
The dataset lives in `examples/data/*.csv`; regenerate it with
`asql query examples/northwind.sql` (or `make examples`, which does that then builds
every report). Build any example from the repo root:

- `growth_dashboard.sql` — the broad one: ~20 chart intents, every section layout,
  `-- filter:`, `facet`, `ma-field`, `series-color`/`series-dash`, `target`/`event`, and
  a `flow` Sankey in its tabbed appendix. Also the interactive features that stay live
  after `asql build`: a `-- filter:` control bar and a `layout: tabs` section, composed.
- `growth_review.sql` — the same data and story as `growth_dashboard`, written as a
  print-ready decision memo (`format: narrative`): `@narrative` templated prose,
  `@markdown`, an embedded `@image`, KaTeX. Shows "one source, two audiences".
- `experiment_readout.sql` — an A/B test readout: `ci` bands and whiskers, an
  `annotation` and `segment` callout, a build-time `refreshed-at`. Self-contained.
- `segment_scorecard.sql` — Few-style scorecard decorations on `table`/`kpi`
  (`lights`, bullet-in-cell, delta badges, sparklines) plus `-- slider:` and
  `-- slider-range:`.

`experiment_readout.sql` and `segment_scorecard.sql` build with `themes/nordic.css`
(`make examples` already passes it); `growth_dashboard.sql`/`growth_review.sql` stay on
the default look, matching the screenshots in the top-level README.

`growth_dashboard.sql` / `growth_review.sql` follow the "lead with the recommendation"
structure — see `docs/research/2026-08-27-analytical-intentions-and-visualizations.md`
and the `asql-exec` skill.
