---
name: asql-exec
description: Use when building or reviewing an asql report for an executive or stakeholder audience — "make an exec report / board deck / QBR from this data", "present these numbers to leadership", "make this dashboard exec-ready", or reviewing an existing .sql report before it goes to a decision-maker. Adds a lead-with-the-decision workflow and a review gate that challenges buried leads, unsupported claims, inconsistencies, and bad charts. Layers on top of the `asql` skill, which handles all asql syntax and mechanics.
---

# Executive & Stakeholder Reports with asql

## What this skill is

The base `asql` skill knows the syntax. This skill knows what makes a report *land with a
decision-maker*: the recommendation comes first, every claim has exactly one chart behind
it, the numbers agree with each other, and nothing is on the page that doesn't move the
argument.

**Load the `asql` skill too.** This skill never restates `-- @` block syntax, chart-intent
names, column-naming conventions, build/preview commands, or error triage — get those from
`asql`'s `SKILL.md` and `reference.md`. This skill is the workflow and the review gate.

## Non-negotiable order

1. **Clarify first** — you may not write SQL until the ask and the recommendation are
   explicit (see below).
2. **Structure** — build the report on the lead-with-the-decision pyramid.
3. **Draft** — write the `.sql`, one claim per chart, using the intention cheatsheet.
4. **Review gate** — run the checklist. Push back on every problem you find; propose the
   fix; do **not** silently paper over it.
5. **Verify** — `asql build`, zero diagnostic cards, then re-check the rendered output
   against the checklist.

---

## Step 1 — Clarifying questions (ask one at a time)

Do not skip these even if the user "just wants a quick dashboard". If the user can't
answer the first two, the report has no job to do — say so.

1. **Who is the audience and what decision are they making?** (CEO / CFO / board / VP —
   they weight strategy, cost, risk, and operational detail differently.)
2. **What is the single ask?** Approve / fund / greenlight / change course / just inform.
   "Just inform" is legitimate but rare — confirm it's really that.
3. **What is the recommendation, its cost, and its expected impact?** In one or two
   sentences. If the user doesn't have one yet, the analysis isn't finished — help them
   find it before building slides.
4. **What is the time box?** A memo read in 3 minutes and a 30-minute review are different
   documents.
5. **What objections do you expect, and from whom?** These become a section, not a
   surprise in the room.
6. **Monitored over time, or a one-time decision?** Ongoing monitoring / multiple
   analytical cuts → `format: dashboard`. One-time decision, non-technical room, need
   alignment now → `format: narrative`. (See `references/executive-communication.md`.)

Also confirm the data source and the specific metrics available, per the `asql` skill.

---

## Step 2 — Structure (the pyramid)

Frameworks in `references/executive-communication.md`. The shape:

| Order | Block(s) | Purpose |
|---|---|---|
| 1 | `@markdown` **Bottom line** + the report `title:` | The executive summary. Must carry all 5 required elements: takeaway headline (the `title:`), 3-5 key findings (observation + context + implication), the recommendation (action verb + specific action + rationale), one supporting visual, a data/caveat line. Write the recommendation first, headline last. First thing on the page. Detail in `references/executive-communication.md`. |
| 2 | `@section` of 3-4 `kpi` tiles | The numbers that justify the decision. Each with a `delta-field` against a reference (plan, prior period). A number with no comparison is not evidence. |
| 3 | `@section` "Why" — one `@markdown` claim **immediately followed by one chart** | The 2-4 strongest pieces of evidence. One message per visual. |
| 4 | `@section` "What could go wrong" — `@markdown` objection map + backup charts | Pre-empt the pushback. |
| 5 | `@section` "Recommendation" — `@markdown` with owner / timeline / checkpoints | Who does what by when, and how you'll know it worked. |
| 6 | `@section` Appendix, `collapsible: true` (dashboard: `layout: tabs`) | Methodology and detail. Not required reading. |

`references/report-template.sql` is an annotated skeleton — start from it.

Rules:
- **Two to four supporting points, not ten.** If everything is important, nothing is.
- **One chart per claim.** If a claim needs two charts, it's two claims — or the claim is
  too broad.
- **Frame percentages as money or units** where you can ("3% SMB churn ≈ $0.9M ARR/yr").
- **Translate jargon.** "R² of 0.87" → "the forecast has been within 5% eight months of
  ten."

---

## Step 3 — Chart selection

Use `references/intention-cheatsheet.md` (distilled from
`docs/research/2026-08-27-analytical-intentions-and-visualizations.md`). Quick version:

- Change over time → `trend` (add `target:` / `event:` reference lines to make the point).
- "How far from plan / last year?" → `deviation`, with `actual - plan AS value` (signed).
  Diverging bars around zero, green above / red below, sorted by variance.
- Rank / top-N → `ranking` (order in SQL).
- Parts of a whole → a stacked bar (or `comparison` if the parts don't need to read as one
  whole). **Avoid pie charts in executive reports** — angle/area is hard to compare and to
  rank; a sorted bar does the same job better. `composition` currently emits a pie for ≤3
  categories, so use `comparison` or a 100%-stacked bar instead.
- Spread of one number → `distribution`; spread across groups → `boxplot`.
- Two numbers related → `relationship` (never imply causation from a dual-axis `combo`).
- Cohort / 2-D magnitude → `heatmap`.
- Sequential contributions bridging a start to an end → `waterfall`.
- Single-path drop-off → `funnel`.
- Headline number → `kpi` **with a delta or a target** — never bare.

---

## Step 4 — The review gate (challenge, don't fix silently)

Before you say the report is done, check every item. For each problem: **state it, show
where, propose the fix, and ask the user to confirm before you change their SQL.** The
full list with examples is in `references/review-checklist.md`.

- **Buried lead** — the headline finding is not in block 1, or not visible without
  scrolling. Move it up.
- **No decision** — there is no stated ask or recommendation. Stop and get one.
- **Unsupported claim** — an `@markdown` assertion with no adjacent chart, OR a chart
  whose data doesn't actually show the claimed effect. Check the direction and magnitude
  against the query result, not the chart title.
- **Inconsistency** — the same quantity differs between a KPI, a chart, and the table.
  Reconcile before shipping.
- **No point** — a chart you could delete without weakening the argument. Delete it.
- **Bad chart** — any pie chart (use a sorted bar); truncated axis exaggerating a change; dual-axis
  implying causation; spaghetti line (>5-8 series unfaceted); `distribution` where a
  `trend` was meant; missing units or axis labels; a `kpi` with no reference point.
- **Over-length** — more than ~7 primary visuals above the appendix. Cut or demote.
- **Weak objection handling** — expected pushback isn't addressed anywhere.

If the user insists on keeping something the checklist flags, that's their call — note the
risk once and move on.

---

## Step 5 — Verify

Per the `asql` skill: `asql build <file>.sql`, then **look at the output** for red
diagnostic cards (a broken block doesn't fail the build). Then re-read the rendered report
top to bottom once more against Step 4 — problems that were invisible in the SQL often
jump out in the rendered layout.

## Files in this skill

- `references/executive-communication.md` — the frameworks and their sources.
- `references/intention-cheatsheet.md` — intent → when to use → common mistake.
- `references/report-template.sql` — annotated skeleton to start from.
- `references/review-checklist.md` — the Step 4 gate, expanded with examples.
