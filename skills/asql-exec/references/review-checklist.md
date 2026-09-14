# The review gate

Run every item before declaring a report done. For each hit: **state the problem, point
to the block, propose the fix, ask the user to confirm before editing their SQL.** Never
silently rewrite around a problem.

If, after review, the rendered `.sql` still trips a check and the user has chosen to keep
it that way, note the risk once and stop re-raising it.

---

## 1. Buried lead

- **Test:** is the single most important finding stated in the first `@markdown` block,
  and visible without scrolling?
- **Fail looks like:** report opens with scope/methodology/data-dictionary; the real
  finding is in section 3.
- **Fix:** move the finding to a `@markdown` "Bottom line" block at position 1:
  recommendation + cost + impact + the ask.

## 2. No decision

- **Test:** is there an explicit ask (approve / fund / greenlight / change course) and a
  recommendation with a cost and an expected impact?
- **Fail looks like:** "Here's how Q3 went." — a status update posing as a decision memo.
- **Fix:** stop. Ask the user what decision this supports. If there genuinely isn't one,
  relabel it as an FYI and shorten it drastically.

## 3. Unsupported claim

- **Test A:** does every `@markdown` claim have exactly one chart adjacent to it?
- **Test B:** does that chart's *data* actually show the claimed effect? Read the query
  result — check direction and magnitude — don't trust the chart title.
- **Fail looks like:** "Churn is improving" above a chart whose last three points tick up;
  "Enterprise is our biggest segment" with no chart; a 2% change described as "a surge".
- **Fix:** correct the claim to match the data, or swap in the chart that supports it, or
  cut the claim.

## 4. Inconsistency

- **Test:** does each quantity have the same value everywhere it appears (KPI tile vs.
  chart vs. appendix table vs. prose)?
- **Fail looks like:** KPI says $1.68M, the trend's last point is $1.6M, the table totals
  $1.71M — different date ranges or filters not reconciled.
- **Fix:** pick one definition, apply it everywhere (a shared `@setup` view helps), state
  the as-of date.

## 5. No point

- **Test:** for each chart — "if I deleted this, would the argument be weaker?" If no,
  it's decoration.
- **Fail looks like:** a chart included because the data was handy, not because it moves
  the recommendation.
- **Fix:** delete it, or move it to the appendix if it's genuine backup for an objection.

## 6. Bad chart

- Pie / `composition` with more than 3 slices → stacked bar.
- Truncated / non-zero axis on a bar chart, or a scale chosen to exaggerate a change.
- Dual-axis `combo` positioned to imply causation between the two series.
- Spaghetti: a `trend` with more than ~5-8 series and no `facet:`.
- `distribution` used where the question was "how did it change over time" (→ `trend`).
- Missing units, missing axis labels, unformatted raw numbers (`format: dollar` / `pct`).
- A `kpi` with no `delta-field` and no `target` — no reference point.
- `heatmap` with a diverging (red-white-blue) scale for a pure-magnitude measure.

## 7. Over-length

- **Test:** count the primary visuals above the appendix. More than ~7 is too many for a
  decision meeting.
- **Fix:** demote the weakest to the collapsible appendix, or merge claims.

## 8. Weak objection handling

- **Test:** is there a "What could go wrong" / objection section, and does it name the
  pushback the user said to expect (from Step 1 question 5)?
- **Fail looks like:** the obvious counter-argument ("but SMB is still growing") appears
  nowhere.
- **Fix:** add an objection-map `@markdown` block with a one-paragraph response per
  objection, plus any backup chart needed.

## 9. Colour and accessibility

- Red/green as the *only* signal (colour-blind readers) — pair with position or a label.
- More than ~5 categorical colours in one chart.
- Colour used decoratively rather than to direct attention to the one thing that matters.
