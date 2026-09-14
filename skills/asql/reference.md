# asql reference

Full syntax beyond SKILL.md's basics. A report is a sequence of blocks, each starting at a
line matching `-- @<type>` and running to the next such line or end of file.

## `-- @report` (report-level metadata, no SQL)

```sql
-- @report
-- title: My Report
-- subtitle: June 2026
-- layout: grid_2x2
-- format: narrative
-- description: Optional longer description
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
-- filter: region
```

- `layout`: `single` (default) or `grid_2x2`/`grid_3x2` — applies report-wide unless you use
  `@section:` blocks, in which case each section sets its own layout instead.
- `format`: `dashboard` (default, interactive Vega-Lite charts) or `narrative` — a
  print-oriented, single-column static-SVG layout with serif body copy. Pick `narrative`
  when the user wants something that reads like a document/memo, or that prints cleanly.
- `brand`/`team`/`date-range`/`experiment-id`/`generated-date`/`dataset-version` render as
  small chrome text in the masthead if set; all optional.
- `refreshed-at` (dashboard format only) renders as a floating "Updated <value>" badge in
  the top-right corner of the masthead — distinct from the chrome-line `generated-date`, use
  it when the user wants the last-refreshed time visually prominent rather than buried in
  the chrome text. A value with a leading `= ` is a SQL scalar expression evaluated at build
  time (e.g. `refreshed-at: = CURRENT_TIMESTAMP`, or `= MAX(order_date) FROM some_view` with
  the view in `@setup`); its result replaces the string. A failed expression shows
  `unavailable` and never breaks the build.
- `max-width` constrains the report's content column width (dashboard format only).
- `toc: true` adds a table of contents built from every labeled `@section:` (sections with
  no label, or an explicit `label_visible: false`, are skipped). Renders as a floating
  left sidebar in dashboard format (only above a 1600px viewport width — it hides rather
  than risk overlapping the content column below that) or an inline block right after the
  masthead in narrative format. Static jump-links only, no active-section highlighting.
- `filter: <column>` (dashboard format only) adds a sticky control bar of `<select>`
  dropdowns above the report; picking a value live-filters every chart whose result
  includes that column, with no rebuild. Multiple columns: `filter: region; channel` (or
  repeat the line). Details in the **Interactive filters** section below.
- `slider: <column>` — same as `filter`, but a discrete range-input slider instead of a
  dropdown. `slider-range: <column>` — a min/max range slider on a numeric column. A column
  can be in only one of `filter`/`slider`/`slider-range`.
- `filter-exclusive: <column>` drops the "All" option from that column's `filter` dropdown,
  forcing the browser's default first value. Same `;`/`,`-separated list shape as `filter`;
  a column must also be listed in `filter` to have any effect.

## Interactive filters (`-- filter:`, dashboard only)

`-- filter: region` on the `@report` block renders a sticky bar with one dropdown per
named column (options = the distinct values asql saw across all blocks, plus "All").
Changing a dropdown re-filters, client-side, every chart whose SQL result carries that
column — the rest of the report is untouched.

- A chart is filtered if its result has a column named exactly `<column>` **or** aliases
  one to it (`SELECT acquisition_channel AS series` is matched — asql resolves the alias).
  Charts that don't have the column are left alone.
- **Not** filtered: `kpi` and `table` cards, and the pre-derived intents `funnel`,
  `waterfall`, `bump`, and `correlation-matrix` (they ship computed rows, not raw data).
  The bar carries a muted "filters charts only" note. `flow` is never filtered either —
  it's a raw Vega spec with no filter-signal wiring at all.
- The current selection is written to the URL hash (`#region=East`), so a filtered view
  is a shareable link and survives reload.
- Multi-series charts also get automatic legend-click isolation (click a legend entry to
  dim the others) — this is on by default whenever `series` resolves to >1 value, no
  metadata needed.
- `trend`/`area`/`scatter`/`bubble` charts can opt in to scroll-zoom + drag-pan with
  `-- zoom: xy` (or `x` / `y`). Off by default. See the `zoom` row in the overrides table.
- `-- slider: region` renders the same control as a discrete slider (drag or arrow keys
  through All + every distinct value) instead of a dropdown — same participation rule,
  signal, and hash sync as `filter`.
- `-- slider-range: deal_size` renders a min/max range slider over a numeric column's
  data-min..data-max. It writes one signal holding `"min..max"` and the chart's filter
  becomes a numeric range check instead of an equality check; the hash carries it as
  `#deal_size=300..12000`.

## `-- @setup` (runs once before every block's query; no card of its own)

```sql
-- @setup
CREATE OR REPLACE VIEW orders AS (
    SELECT * FROM read_csv_auto('orders.csv') WHERE status != 'cancelled'
);
```

Plain SQL, no metadata, placed right after `-- @report`. Use this instead of repeating the
same `WITH ... AS (...)` CTE in every block that needs the same prep work. Always use
`CREATE OR REPLACE` (not plain `CREATE`) - this SQL runs again before *every* block's
query, not once for the whole report: a full build shares one DuckDB connection across all
blocks, but each preview-mode block editor opens its own fresh, isolated connection per
request and needs to see the same setup again to have anything to reference.
`CREATE OR REPLACE VIEW`/`TABLE` make that re-run a no-op instead of an error. Multiple
`-- @setup` blocks are allowed and run in document order.

## `-- @section: <name>` (splits the report into independently laid-out groups)

```sql
-- @section: overview
-- label: Overview
-- layout: two-col
-- collapsible: true

-- @chart: trend
...
```

`layout`: `single`, `full`, `grid_2x2`/`two-col`, `grid_3x2`/`three-col`, `kpi-grid`,
`sidebar-main`, `hero`, `tabs`. `label` is the heading shown above the section.
`collapsible: true` renders it as a `<details>` the viewer can collapse. Skip `@section`
entirely and every block lands in one implicit section using the report-level `layout`.

`layout: tabs` (dashboard format only) renders a real tab bar when the section has **more
than one card** — one tab per card, the tab label taken from each card's `title`. A
one-card `tabs` section falls back to the normal single-column layout. A chart sitting on
an unopened tab embeds the first time that tab is shown (Vega can't lay out inside a
hidden container), so no chart renders 0-width. In narrative format `tabs` just stacks the
cards.

## `-- @chart: <intent>` (metadata lines, then one SQL statement)

```sql
-- @chart: trend
-- title: Monthly Revenue
-- subtitle: Last 12 months

SELECT ...
```

### Explicit overrides

Add any of these metadata lines when column-naming inference isn't enough:

| Key | Effect |
|---|---|
| `@x`, `@y`, `@series` (note the `@`) | Force which column is which — always wins over inference. Wrong column name → error card listing what's actually available. |
| `x-label`, `y-label`, `series-label` | Relabel axes/legend (raw column name is the default). |
| `format` | A [d3-format](https://d3js.org/d3-format) string for the numeric axis + tooltip, or a shortcut: `pct` (`.0%`), `dollar` (`$,.0f`), `kilo` (`~s`). |
| `x-format` | For a temporal x-axis, e.g. `week` buckets ticks by week. |
| `scale` | `heatmap` only — `diverging` gives a red↔blue ramp centred at 0 (for change/variance data). Default is sequential. |
| `bands` | `bullet` only — ascending qualitative-range thresholds (`60, 80, 120`) shaded behind the measure bar. |
| `fit` | `relationship` only — `true` overlays a linear regression line on the scatter. |
| `facet: <column>` | Split into small multiples, one panel per distinct value of a categorical column. |
| `target` | Fixed reference line(s): `500000 \| Annual Goal \| #d4a017; 750000 \| Stretch Goal` — `;`-separated `value \| label \| color` entries, label/color optional. Compared against the quantitative axis. On a `kpi` it renders an attainment caption ("83% of target") instead of a line — the first entry's label becomes the caption suffix. |
| `event` | Fixed reference line(s) on the temporal axis, same `value \| label \| color` shape, e.g. `2025-06-15 \| Product Launch`. |
| `annotation` | `trend`/`area` only — floating text callout(s) at an x position, pinned to the plot top: `2026-03-01 \| Price change \| #da438a` — `;`-separated `x \| text \| color`, color optional. Keeps its own data, so it survives chart filtering. |
| `segment` | `trend`/`area` only — partial-width horizontal reference rule(s) spanning `x-start`..`x-end` at a constant `y`: `120 \| 2026-01-01 \| 2026-06-30 \| H1 avg \| #26468a` — `;`-separated `y \| x-start \| x-end \| label \| color`, label/color optional, `y` must be numeric. |
| `y-zero: false` | Y-axis starts at the data min instead of the default zero baseline, on charts whose y-axis is the numeric measure (`trend`, `area`, `scatter`, `bubble`, a vertical `bar`). |
| `show-points` | `trend` only — `false` hides a short single-series line's point markers (normally shown when the series has ≤12 rows); `true` forces them on regardless of row count or series count (works on a multi-series line too). |
| `lights` | `table`/`kpi` only — exactly two ascending thresholds (`0.8, 0.95`) deriving a good/warn/bad status dot from the `value`/`metric` column when there's no explicit `status` column. See the Few-style scorecard section below. |
| `delta-field` | Column holding a signed delta for a `kpi` card → renders a ▲/▼ badge (green up, red down). |
| `delta-label` | Text shown next to the delta badge. |
| `delta-neutral: true` | Always render the delta badge gray regardless of sign. |
| `ma-field` | Column holding a pre-computed moving average, overlaid as a second line — `trend` only, single-series only. |
| `ci` | Two columns holding a pre-computed interval: `ci_low \| ci_high` (asql does no stats). `trend` → translucent band, one colour-matched band per series (keep to ≤8 distinct series). `comparison`/`ranking` → error-bar whiskers, single-series only. Any other chart type (`area` included) is an error. |
| `labels: true` | Show each bar's value as a text label. |
| `grouped: true` | Dodge a multi-series bar's segments side-by-side instead of stacking. Silently ignored off a multi-series bar. |
| `show-total: true` | Print the summed total above each bar of a **stacked** multi-series bar. Ignored when `grouped` is also set, or off a multi-series bar. |
| `mark-color` | Hex fill for a **single-series bar / line / area / scatter** mark (`#da438a`). Named error on a multi-series chart (series colour scale wins) or on any chart whose colour is set by the data (pie, heatmap, deviation, stacked bar, bullet, combo, funnel, waterfall, slopegraph, bump, correlation matrix, flow). |
| `series-color` | Multi-series `trend`/`area` — per-series colour. Comma-separated `<series value> <colour>` (colour is the last token, so `New York #26468a` works). Unlisted series keep the palette. Silently ignored on single-series or other chart types. |
| `series-dash` | Multi-series `trend` (line only) — per-series stroke. Comma-separated `<series value> [dashed\|dotted]`, default `dashed`. Unlisted series stay solid. Ignored on `area` / single-series / other chart types. |
| `zoom` | Opt in to scroll-zoom + drag-pan on a `trend`/`area`/`scatter`/`bubble` chart (dashboard). `-- zoom: xy` (both axes), `x`, or `y`. Off unless set. Ignored on faceted charts, charts carrying an overlay (reference line / CI band / MA / annotation), and narrative format. |
| `height` | Override a chart/image's rendered height (e.g. `300px`); width stays proportional. |

`facet`, `format`, `target`, `event`, `annotation`, and `segment` aren't supported on
`combo`/`funnel`/`waterfall` (different spec shape) or, for `target`/`event`, on
`pie`/`heatmap`/`distribution`'s histogram (no comparable axis) — using them there produces
a named error card instead of silently doing nothing. `annotation`/`segment` are rejected
on any chart that isn't `trend` or `area`. `flow` rejects `facet`/`target`/`event`/
`annotation`/`segment` the same way, but allows `format` (it formats the node/link tooltip
values, computed in V rather than left to a Vega-Lite encoding).

### Few-style scorecards on `table` / `kpi`

Not a new chart type — `table` and single-value `kpi` cards auto-detect a fixed set of
reserved column names (case-insensitive) and decorate the `value`/`metric` column's cell
with them, hiding the decoration columns themselves from the table's header:

| Column name | Effect |
|---|---|
| `value` or `metric` | The primary measure the other decorations attach to. Required for `status`/`target`/`delta` to have any effect on a `table`; on `kpi` this is just `@y`. |
| `spark` or `sparkline` | An array-as-text column (e.g. a DuckDB `LIST` cast to text, `[1.0, 2.0, 3.0]`) → a small inline sparkline. Stays visible as its own column on `table`. |
| `status` | Text values `good`/`warn`/`bad` → a colored dot beside the value. Takes priority over `lights`. |
| `target` | A numeric column → combines with `value` into a compact bullet-in-cell (fill bar + target tick), replacing the plain number. |
| `delta` | A numeric column → a ▲/▼ badge after the value, same styling as `kpi`'s `delta-field`. On `kpi`, `delta-field` takes precedence if set; a bare `delta` column is used automatically otherwise. |

`target`/`delta` columns don't count toward `kpi`'s "2-6 numeric columns → tiles"
auto-promotion — they're decorations on the primary value, not separate KPI measures.

## `-- @narrative` (templated prose block, works in either report format)

```sql
-- @narrative
-- title: Summary

SELECT SUM(revenue) AS revenue, COUNT(*) AS orders FROM orders;

-- Total revenue was {{ revenue }} across {{ orders }} orders.
```

Same shape as `@chart`: metadata, one SQL statement, then a blank line, then the prose
template as more `--`-prefixed lines (keeps the whole file valid SQL). `{{ column_name }}`
substitutes a result column. The query must return exactly one row; an unknown `{{ key }}`
or a multi-row result renders as an error card instead of breaking the report.

## `-- @markdown` (static prose, no query)

```sql
-- @markdown
-- title: Methodology

-- We define active users as anyone with **at least one** session in the trailing 28 days.
-- - Excludes internal/test accounts
-- - Timezone: UTC
```

Everything after the metadata lines is Markdown, rendered to HTML. No SQL statement at all.
Every body line **must** stay `--`-prefixed (asql strips the leading `-- ` before rendering),
exactly like `@narrative`'s prose template — this keeps the whole file valid, pipeable SQL.
A blank line separates the metadata from the body. Example with wrapped prose:

```sql
-- @markdown
-- title: Notes

-- Definitions: cost to serve = payroll processing + support + infrastructure + compliance
-- cost, from `cost_to_serve`. Automation rate, on-time and SLA flags from `payroll_runs`.
-- Error impact from `payroll_errors`. Productivity from `ops_fte_monthly`. All figures cover
-- Jan 2023 – Dec 2024.
```

## Math (KaTeX)

Prose in `@markdown` bodies and `@narrative` templates renders LaTeX math via KaTeX:
`$…$` for inline, `$$…$$` for a centered display block. Works in both report formats.

```sql
-- @markdown
-- title: Method

-- Pearson correlation is $r = \dfrac{\sum (x_i - \bar x)(y_i - \bar y)}{\sqrt{\sum (x_i - \bar x)^2}\,\sqrt{\sum (y_i - \bar y)^2}}$.
--
-- $$\text{CAC} = \frac{\text{sales + marketing spend}}{\text{new customers}}$$
```

Math rendering is scoped to prose only — KPI values and table cells are never touched, so
a bare `$` used as a currency sign (`$5.00`) in those is safe. Inside a `@markdown` /
`@narrative` body that also needs a literal dollar sign, write `\$`.

## `-- @image` (embed a local image file)

```sql
-- @image
-- title: Architecture
-- path: diagrams/pipeline.png
-- caption: Data pipeline overview
-- height: 400px
```

`path` (required; `src` is an accepted alias) is resolved relative to the report file's own
directory and embedded as a base64 data URI (keeps the output self-contained). `caption` and
`height` are optional.
A missing/unreadable file renders as an error card rather than failing the whole build.

## Data sources

Anything DuckDB can read directly, local or remote, no ingestion step:

```sql
FROM 'data/sales.parquet'
FROM read_csv_auto('data/orders.csv')
FROM read_csv_auto('https://example.com/exports/orders.csv')
```

To read another DuckDB database, attach it in `-- @setup` and query the alias
(`ATTACH IF NOT EXISTS 'warehouse.duckdb' AS wh (READ_ONLY);` then `FROM wh.orders`).

## Build / preview / theme

```bash
asql build report.sql                          # writes report.html next to it
asql build --fresh report.sql                   # ignore the query-result cache
asql build --theme themes/midnight.css report.sql
asql preview --port 4321 report.sql             # live-reload dev server
asql preview --theme themes/sepia.css report.sql
asql query query.sql                           # run a flat .sql file, print rows as a table
asql query --format csv query.sql              # ...as CSV
```

`asql query` runs a flat `.sql` file through DuckDB and prints the resulting rows. It
ignores `-- @` blocks entirely, including `@setup`, so a report file that depends on setup
views will error — point it at a scratch `.sql` or a self-contained query.

**Flags go before the file path** — `asql preview report.sql --port 4321` silently falls
back to the default instead of erroring (a quirk of the CLI parser).

`--theme <file>` layers a CSS file over the default stylesheet. A theme file overrides CSS
custom properties (`--canvas`, `--paper`, `--ink`, `--accent`, `--line`, `--positive`,
`--negative`, `--sans`, `--mono`, ...) and/or chart colors specifically via the
`--chart-*` set: `--chart-accent`, `--chart-palette` (comma-separated hex list — the
default is a 10-colour house palette), `--chart-ink`, `--chart-grid`, `--chart-positive`,
`--chart-negative`, `--chart-diverging`, `--chart-sequential`. Each `--chart-*` falls back
to its shell equivalent, then a built-in default. Several ready-made themes
ship in asql's own repo under `themes/` (`midnight`, `sepia`, `nordic`, `forest`, `mono`) —
copy one and tweak it, or write a `:root { ... }` block from scratch. Only relevant when
the user asks for custom colors/branding on a report.

## Viewing a built report (dashboard format)

Every chart card has a small "..." button next to its title (dashboard format only, since
narrative format renders charts as static SVG) letting the viewer save that one chart as a
PNG or SVG — no export step needed from the report author.

## Error handling

A broken block (bad SQL, an intent that doesn't fit the data shape, an unknown `{{ key }}`)
renders as a red diagnostic card in place, with a message naming what was detected — it
never breaks the rest of the report. Always look for these after building; they're easy to
miss since the build itself still "succeeds."
