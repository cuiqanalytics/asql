# Executive communication — the frameworks

Distilled from four practitioner guides (sources at the bottom). They differ in wording
and agree almost completely in substance.

## The core mindset shift

> Executives don't need to understand your process. They need to know what to do next and
> why the data supports it.

Chronological / methodology-first presentations lose a time-pressured, context-switching
audience. Invert it: conclusion first, evidence second, method in the appendix.

## Lead with the decision (datastorycoach)

**1. Lead with the decision.** Open with recommendation + cost + expected business impact
+ a one-line bridge to the evidence. Target: 30-45 seconds spoken, or the first
`@markdown` block.

**2. Support with two to three data points.** Only the strongest evidence that *directly*
supports the decision. Pyramid: decision on top, supporting arguments below, methodology
held in reserve. For each point ask: what makes them say yes, what makes them hesitate,
what adds credibility.

**3. Anticipate objections.** Build an objection map before presenting — likely concerns
(sample size, timeframe, alternative explanations, political cost) each with a prepared
response and, if needed, a backup chart.

Pre-flight checklist: write the decision statement (1-2 sentences); pick exactly three
supporting points; build the objection map; practise the opening aloud; move everything
else to the appendix.

## The executive-summary block — 5 required elements (datastorycoach)

The first `@markdown` block (and the report `title:`) is the executive summary. It must
contain all five:

1. **Headline that states the takeaway** — the report `title:`. Formula:
   `[key metric] + [direction / comparison] + [primary driver]`. Not "Q3 Review", not
   "Executive Summary" — a specific conclusion ("SMB churn is eroding NRR faster than
   Enterprise expansion can offset").
2. **Three to five key findings** — each as *observation + context + implication*, not a
   bare number.
3. **A clear recommendation / next step** — `[action verb] + [specific action] +
   [rationale]`. Answers "what do you want us to do?"
4. **One supporting visual** — a single chart or KPI callout, not a grid.
5. **A confidence / context line** — data source, time period, caveats.

Write them in this order: recommendation first → top findings → headline → pick the one
visual → context line. ~15 minutes. No vague phrasing ("mixed results", "trends
observed"); no passive voice; recommendation on the summary itself, never saved for the
end.

## The 4-step structure (visora)

1. **Executive summary** — the whole story in the first few minutes / screens.
2. **Break down the complexity** — group by business priority (revenue, retention,
   efficiency), not by data source; plain language.
3. **Visual storytelling** — one message per visual; colour used only to direct
   attention; honest scales and labelled axes; remove decoration.
4. **Guide the decision** — connect every recommendation to revenue / cost / risk;
   prioritise by impact × feasibility; assign owners and dates; propose checkpoints.

## Prioritise, structure, translate, connect, enable (sigma)

- **Prioritise ruthlessly** — does this insight change a decision? Does it match a
  stakeholder priority? If not, cut it.
- **Structure for clarity** — headline first, then supporting detail; whitespace.
- **Translate technical language** — "high R²" → "accurate 91% of the time".
- **Connect to concrete impact** — "3% churn = $537K/yr"; tie to role-specific outcomes.
- **Enable action** — clear next steps, explicit ownership, defined success criteria.

Sigma's 30-second checklist: core insight stated in the first 30 seconds · a non-technical
person can read the chart · the insight connects to a business priority · a specific
decision is required · objections anticipated · next-step ownership is clear.

## Interactive dashboard vs static report

| Use `format: dashboard` (interactive) | Use `format: narrative` (static) |
|---|---|
| Data refreshed often, monitored continuously | One-time decision, fixed conclusion |
| Audience wants to slice it themselves | Audience unfamiliar with data tools |
| Exploring complex relationships | You need alignment in the room now |
| A metrics wall the team watches weekly | A memo read once and filed |

An executive *decision memo* is almost always the static case. A *health monitor* is the
interactive case. When in doubt for a decision meeting, ship the narrative.

## Common mistakes (all four guides)

- Starting with context/method instead of the conclusion.
- Overloading a slide/card — more than one message, more than ~10 seconds to parse.
- No explicit ask (approval, resources, a go/no-go).
- Numbers with no reference point (no vs-plan, no vs-prior, no target).
- Ignoring the political implications of a recommendation.
- Recommendations with no measurable outcome or owner.
- Leaving the room without agreement on what happens next.

## Sources

- datastorycoach.ai — "Presenting Data to Executives & Stakeholders" and "The Executive Summary Slide"
- visora.co — "How to Present Complex Data to Executives"
- sigmacomputing.com — "Stakeholder Data Communication"
- FT Visual Vocabulary + Flourish / Highcharts chart-choice guides (chart selection)
