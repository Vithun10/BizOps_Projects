# FLOW: KPI Definitions
Rules set BEFORE analysis. Units: days unless stated. Time zone: IST. Month cutoff: last day of month, 23:59:59.

| KPI | Numerator / formula | Denominator / population | Exclusions | Window | Unit |
|---|---|---|---|---|---|
| End-to-end cycle time | completed_at - created_at; report mean, median, P90 | Applications with final_status = Completed | Cancelled and open | By completion month | Calendar days (primary), working days (secondary) |
| Stage duration | exited_at - entered_at per stage episode | Closed stage episodes | Episodes with invalid timestamps (flagged) | By stage entry month | Calendar days |
| Queue time | first task assigned_at - stage entered_at | Stage episodes with at least one task | Episodes with no tasks | By stage entry month | Calendar days |
| Monthly throughput | Count of applications with completed_at in the month | n/a | Cancelled | Calendar month | Count |
| Monthly demand | Count of applications with created_at in the month | n/a | none | Calendar month | Count |
| Closing backlog | Opening backlog + received - completed - cancelled | n/a | none | Month end | Count |
| Rework rate | Applications with at least 1 qualifying rework event | Eligible applications: those that exited Stage 1 at least once, excluding those cancelled before exiting Stage 1 | Rework events with resolution_status = Invalid | Cohort by created month | % |
| SLA attainment | Completed cases with cycle time <= 35 calendar days | All Completed applications | Cancelled and open | By completion month | % |
| Cost per completion | (Stage labour + rework labour + allocated tools/overhead) / completions | Completed applications in period | Revenue-delay costs (kept out of cost and counted only as a separate benefit) | Calendar month | INR |
| Capacity utilisation | Assigned task hours / available hours (monthly_capacity_hours; already FTE-adjusted; do not multiply by FTE_fraction again) | Active owners in the month | Owners outside active_from to active_to | Calendar month | % |

## Qualifying rework event
A row in rework_events where the application returned to an earlier stage or a correction was required, and estimated_minutes > 0.

## Backlog rule
An application is open at a cutoff if created_at <= cutoff and it has not been completed or cancelled by the cutoff.

## SLA decision (proposed)
35 calendar days for all applications. Results are also shown by complexity band so that the target is not unfair to complex cases. Change only before the analysis starts.

## Consistency rule
SQL, Excel and Power BI must use these definitions unchanged. Any change is logged here with a date.

## Change log
- **17 October 2026:** Clarified that `monthly_capacity_hours` is already FTE-adjusted in the supplied model; do not multiply it by `FTE_fraction` a second time. Utilisation should only be calculated when valid assigned-task hours and comparable available-hours data are available.


## Capacity and utilisation clarification

Capacity hours are already FTE-adjusted in the source data. Do not multiply `monthly_capacity_hours` by `FTE_fraction` a second time. Available capacity is a modelled planning input and is not, by itself, a measure of productive labour utilisation.

## Change log

- **2026-10-17:** Clarified FTE-adjusted capacity treatment and distinguished available capacity from measured employee utilisation.
