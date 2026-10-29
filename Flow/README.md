# Project FLOW — Customer Onboarding Throughput Transformation

## Overview
Project FLOW is a synthetic-data business analysis and operational improvement case study for Northstar Cloud Services, a fictional B2B SaaS company. It examines customer-onboarding throughput, stage delays, backlog, rework, workload and potential process interventions.

- **Reporting period:** October 2025–September 2026
- **Data status:** Synthetic; no live customer or client data
- **Decision question:** Can Northstar complete at least 240 onboardings per month with a redesigned process, is additional staffing needed, and which intervention has the best risk-adjusted economics?

## Authoritative process sequence
1. Intake & Submission — Sales
2. Handoff Acceptance — RevOps
3. Contract & Legal Review — Legal
4. Finance Approval — Finance
5. Implementation Setup — Implementation
6. Go-live Readiness — Implementation
7. Activation Handoff — Customer Success

The sequence is defined in `assumptions/process_stages_and_scope.md`. Do not reorder stages based on bottleneck rank or chart values.

## Allowed rework loops
- Handoff Acceptance → Intake & Submission: missing or incorrect information.
- Contract & Legal Review → Intake & Submission: missing contract documents.
- Finance Approval → Handoff Acceptance: incorrect credit or billing details.
- Implementation Setup → Handoff Acceptance: unclear requirements.

Preserve application identity and stage history when work is returned.

## Terminal statuses
- **Completed:** passed Activation Handoff.
- **Cancelled:** customer withdrew or the deal was lost.
- **Open:** still in progress at the reporting cutoff.

## KPI and time conventions
See `assumptions/KPI_definitions.md`. Calendar time is the primary elapsed-time measure; working time is secondary. Queue time is measured from stage entry to first task assignment in that stage. Task assigned-to-completed duration is an in-progress proxy, not direct hands-on effort. Capacity hours are already FTE-adjusted and must not be multiplied by FTE fraction again.

## Project contents
- `assumptions/` — process stages/scope, KPI definitions, data-generation assumptions and `financial_model_assumptions.md`.
- `data/raw/` — synthetic source CSVs for applications, calendar, owners, rework events, stage history and tasks.
- `data/processed/` — derived KPI datasets, including `kpi_stage_metrics.csv`.
- `data/data_quality_report.md` — row counts, reconciliation and injected issue categories.
- `data/generation_summary.txt` — data-generation summary.
- `data/generate_flow_data.py` — data-generation script (seed 20261013).
- `excel/data_dictionary.xlsx` — data dictionary.
- `sql/` — table creation, profiling, transformation, KPI analysis and validation scripts.
- `sql/README_run_order.md` — SQL execution order.
- `process/` — process maps and operating-model documentation, where included.
- `powerbi/screenshots/` — dashboard screenshots, where included.

## Reproducibility and Phase 3 validation status
The renamed generator was re-run with seed `20261013`; the resulting `generation_summary.txt` matched the saved summary byte-for-byte. It reports 2,711 applications, 18,332 stage rows, 21,363 tasks, 604 rework rows and PASS for all 12 monthly backlog reconciliations.

The validation outputs report 12/12 data-quality reconciliation checks, 20/20 scalar validation checks and 12/12 monthly backlog reconciliations passed. Confirm the SQL outputs are available and reproducible before making these claims in a final portfolio presentation.

## Baseline findings
- 2,508 applications received and 2,167 completed during the reporting period.
- Closing open backlog: 360 applications.
- Mean cycle time: 40.8 calendar days; median: 35.1; P90: 70.0.
- SLA attainment: 49.2% of eligible completed cycles met the 35-calendar-day SLA.
- Finance Approval ranks first in the composite bottleneck analysis; this is a prioritisation signal, not proof of sole or causal responsibility.
- 530 applications had qualifying rework among 2,665 eligible applications (19.9%); there were 571 qualifying events.
- The total across injected issue categories is **586 issue instances**, not 586 unique records.

## Power BI scope
The report contains four implemented pages: Executive Report, Process Bottlenecks, Quality & Rework, and Capacity & Workload. The planned Intervention Scenarios page has not been built. Options A–D and conservative/base/optimistic scenarios are evaluated in the Excel decision model; the project does not claim to provide an interactive Power BI scenario comparison.

## Limitations
All data is synthetic. Rework minutes are effort proxies; capacity hours, complexity points and stage episodes are distinct indicators and do not prove employee utilisation. Modelled intervention impacts are projections, not realised savings. Freed capacity must not be described as cash savings unless a real cash cost changes. Current/future process maps, RACI and SOP are case-study artefacts; the future state is proposed, not live or approved.

## Reproduction
1. Review assumptions and KPI definitions.
2. Run SQL scripts in the documented order.
3. Review validation outputs and reconcile KPI definitions.
4. Inspect the Excel decision model assumptions, scenarios and sensitivity outputs.
5. Refresh the Power BI report from validated sources and verify figures before publishing.
6. Use the four-page dashboard screenshots as evidence and disclose that scenario comparison remains Excel-based.


## Power BI implementation scope

The implemented report contains four pages: Executive Report, Process Bottlenecks, Quality & Rework, and Capacity & Workload. The planned Intervention Scenarios page has not been built; scenario analysis remains in the Excel decision model. Four dashboard screenshots are stored in `powerbi/screenshots/`.

## Data-quality issue count

The total is **586 issue instances** across issue categories. It is not a distinct-record count because a record can contain multiple issue types.

## Documentation change log

- **2026-10-17:** Clarified the four-page Power BI scope, Excel-based scenario analysis and the meaning of the 586 issue-instance total.

## Documentation change log
- **2026-10-17:** Renamed the generator to `generate_flow_data.py`, verified reproducibility from seed `20261013`, and clarified the four-page Power BI scope and the 586 issue-instance total.
