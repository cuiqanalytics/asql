# Intention cheatsheet (executive lens)

Distilled from `docs/research/2026-08-27-analytical-intentions-and-visualizations.md`.
Column-naming conventions and override syntax: see the `asql` skill's `reference.md`.

| Analytical question | Intent | Use when | Common mistake to catch in review |
|---|---|---|---|
| How has this changed over time? | `trend` | A measure over dates. Add `target:` / `event:` reference lines so the chart makes the point, not just shows data. | >5-8 unfaceted series (spaghetti) — use `facet:` or filter to the segments that matter. |
| Same, emphasising volume / cumulation | `area` | Single series, or stacked parts summing to a total. | Overlapping (non-stacked) multi-series area — misleads on magnitude. |
| How big, across a few categories? | `comparison` | 3-12 categories on one measure. | Bars not starting at zero; unsorted when there's no natural order. |
| Who's top / bottom? | `ranking` | Ordered top-N. Sort in SQL (`ORDER BY ... LIMIT`). | Using it when you mean "compare magnitudes" (that's `comparison`). |
| How far above/below plan / last year? | `deviation` | Deviation from a reference. Pass `actual - plan AS value` (signed). | Showing raw actual vs. raw plan as two bars — the gap is the story, show the gap. |
| How does the total break down? | `composition` | Parts of a whole. Emits a pie only for ≤3 slices, a 100%-stacked bar for 4+, a stacked area if a date column is present. | Pie with 4+ slices (asql now avoids this). A row of pies over time — that's the stacked-area case. |
| How is one number spread? | `distribution` | One numeric column, histogram. | Feeding it a category column — asql now returns a diagnostic; use `boxplot` for grouped spread. |
| How does spread differ by group? | `boxplot` | A measure per category. | Using it with n < ~10 per group — too few points to read a box. |
| Do these two move together? | `relationship` | Two numeric columns, scatter. | A dual-axis `combo` implying one causes the other. |
| Magnitude across two dimensions / cohorts | `heatmap` | Measure × two categoricals (incl. cohort × age). | Diverging colour scale for pure magnitude — use sequential; keep diverging for change-vs-zero. |
| How do contributions bridge a start to an end? | `waterfall` | Sequential +/- components (MRR bridge, budget variance). | Bars not anchored; too many components (>~8) — group the small ones. |
| Single-path stage drop-off | `funnel` | One linear process. | A branching process — that needs a Sankey (`flow`, proposed), not a funnel. |
| Two measures, different units, shared x | `combo` | e.g. revenue $ + count. Bars = the measure of primary interest. | Two unrelated lines on two axes to imply correlation. |
| The headline number | `kpi` | 1-6 measures, one row. **Always** with `delta-field` or a target. | A bare number with no comparison — near useless to an exec. |
| Anything else / raw detail | `table` | Appendix backup. | Putting a >20-row table above the fold. |

## Reference-line and delta overrides that add executive context

- `target: 100000 | Annual goal | #198038` — a fixed line on the quantitative axis.
- `event: 2025-06-01 | Price change | #b3261e` — a fixed line on the temporal axis.
- `delta-field: change` + `delta-label: vs Q3` — the ▲/▼ badge on a `kpi`.
- `delta-neutral: true` — when "up" isn't automatically good (e.g. churn, cost).
