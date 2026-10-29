# FLOW: Financial Model Assumptions

**Status and as-built summary.** This document records the assumptions set out before the model was built. The completed workbook is `excel/decision_model_Phase2_Final_Corrected.xlsx`; where the two differ, the workbook governs.

- Throughput proxy = average historical completions (180.6/month) × (1 + redesign uplift) + added FTE × throughput per FTE. It is shown uncapped, and capped at demand.
- The gap to the 240 target is measured against the uncapped figure.
- Net first-year impact = rework-cost reduction proxy (redesign options only) − first-year cost. It does not value extra throughput, released capacity or revenue timing.
- Result: in the Base case no option reaches 240. Option D is closest, with a gap of 17.4 cases/month. The recommendation is conditional.
- Not modelled: forecast backlog roll-forward with explicit checks; partial-month capacity proration; cost per completion; a separate net recurring annual impact; and formal benefit classification (cashable, avoidance, capacity released, incremental throughput).

## 1. Purpose
This document explains the assumptions used to evaluate operational interventions for Project FLOW, a synthetic-data onboarding throughput case study. It supports scenario comparison; it is not a budget approval or a claim of realised savings.

## 2. Data and workbook inputs
The workbook uses the synthetic historical baseline and assumptions recorded in `Read Me & Assumptions`. The processed KPI inputs in `data/processed/` are:

- `kpi_bottleneck_evidence.csv`
- `kpi_cycle_time_summary.csv`
- `kpi_monthly_flow.csv`
- `kpi_owner_workload.csv`
- `kpi_rework_drivers.csv`
- `kpi_rework_rate.csv`
- `kpi_stage_metrics.csv`
- `kpi_stage_monthly.csv`
- `kpi_team_monthly_load.csv`

These nine files were present in the supplied `data/processed/` folder at the time of review. The workbook's source and assumptions tabs remain authoritative for the actual formulas and scenario inputs.

## 3. Verified baseline

| Measure | Baseline | Interpretation |
|---|---:|---|
| Reporting period | Oct 2025–Sep 2026 | Synthetic 12-month period |
| Applications received | 2,508 | Monthly demand in period |
| Applications completed | 2,167 | Completions in period |
| Average monthly completions | 180.6 | 2,167 divided by 12, rounded |
| Closing backlog | 360 | Open applications at 30 Sep 2026 |
| Monthly throughput target | 240 | Decision target, not observed performance |
| Mean cycle time | 40.8 days | Calendar days |
| Median cycle time | 35.1 days | Calendar days |
| P90 cycle time | 70.0 days | Calendar days |
| SLA attainment | 49.2% | Eligible completed cycles within 35 calendar days |
| Applications with qualifying rework | 530 / 2,665 eligible | 19.9% |
| Qualifying rework events | 571 | Event count, not unique applications |

## 4. Scenario definitions
The workbook compares four options: A — No change; B — Process redesign; C — Additional staffing; and D — Redesign plus targeted staffing. The scenario and sensitivity tabs contain the editable planning assumptions. Conservative, Base and Optimistic cases are modelled as assumptions, not as observed outcomes.

## 5. Throughput and demand
The model estimates uncapped capacity from the average historical completion baseline, redesign uplift and added staffing throughput. A separate capped throughput figure limits expected completions to demand. The target gap uses the uncapped capacity estimate so the 240 target shortfall remains visible even when demand is lower than target. The capped value is retained to avoid projecting completions above modelled demand.

The workbook does not implement a full forecast backlog roll-forward with explicit month-by-month validation checks. Historical monthly backlog reconciliation is documented in `data/data_quality_report.md`; it should not be confused with a scenario forecast.

## 6. Staffing and capacity
Staffing throughput uses the workbook's additional-throughput-per-FTE assumption and the hours-per-FTE assumption. The model treats source capacity hours as already FTE-adjusted; do not apply FTE fraction twice. **Partial-month capacity proration is not modelled.** Ramp-up assumptions may adjust scenario cost/benefit timing, but they are not a substitute for calendar-day or start-date-specific capacity proration.

## 7. Cost assumptions
The workbook includes scenario cost inputs, one-time redesign cost, hiring cost and annual/recurring cost estimates. First-year cost is modelled from the relevant one-time, hiring and recurring cost components. A separate **cost per completion** measure is not modelled in the current workbook.

## 8. Rework benefit proxy
The model estimates a rework-cost reduction proxy using historical rework effort, the assumed cost rate, the option's rework-reduction assumption and ramp-up adjustment. This benefit proxy is applied only to the redesign options (B and D); Options A and C receive zero redesign-related rework benefit. The proxy is not a verified cash saving and may represent released capacity rather than a reduction in actual spend.

## 9. First-year and recurring impact
Net modelled first-year impact equals the redesign-related rework-cost reduction proxy minus the modelled first-year cost. It does not assign a monetary value to additional throughput, released capacity, avoided costs or revenue timing. The workbook shows recurring annual cost after ramp-up, but a separate **net recurring annual impact** is not modelled.

## 10. Benefit classification
The workbook does not formally classify benefits into cashable savings, cost avoidance, capacity released and incremental throughput. Any decision paper should classify these separately and only describe a benefit as cashable when an actual cash cost changes. Do not add capacity-release proxies to cash savings or count the same benefit in multiple categories.

## 11. Sensitivity and decision rule
The sensitivity tab varies demand growth, redesign uplift, rework reduction, monthly cost per FTE, one-time redesign cost and added throughput per FTE across Conservative, Base and Optimistic cases. The recommendation is conditional: compare target gap, first-year cost, recurring cost and the modelled rework proxy, then validate operational feasibility and benefit realisation before approval.

## 12. Known limitations
- All source records and scenario outcomes are synthetic.
- No option reaches 240 cases/month in the Base case; Option D is closest at approximately 17.4 cases/month below target.
- Forecast backlog roll-forward checks, partial-month capacity proration, cost per completion, separate net recurring annual impact and formal benefit classification are not modelled.
- Rework-cost reduction is a proxy, not verified savings.
- Additional throughput and released capacity are not monetised in net first-year impact.
- Scenario assumptions require stakeholder validation before any operational or financial commitment.

## 13. Reproduction checklist
- [x] Confirm the nine processed `kpi_*.csv` files exist under `data/processed/`.
- [x] Confirm the generator uses seed `20261013` and its regenerated summary matches the saved summary.
- [x] Confirm historical monthly backlog reconciliation passes for all 12 months.
- [x] Confirm the Excel workbook formulas and scenario outputs recalculate.
- [ ] Validate scenario assumptions with operational and finance stakeholders before using the model for a real decision.

## Change log
- **2026-10-17:** Converted the pre-build assumptions into an as-built summary, documented the five requested modelling gaps, verified the nine processed KPI filenames and added reproducibility status for seed `20261013`.
