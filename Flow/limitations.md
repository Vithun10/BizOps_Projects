# Project FLOW — Limitations and Assumptions

## 1. Purpose and synthetic-data status
Project FLOW is a portfolio case study using synthetic data for a fictional B2B SaaS company. It demonstrates analytical and decision-support methods; it does not represent verified performance at a real organisation.

## 2. Dataset and reporting period
The dataset covers October 2025 through September 2026 and contains 2,711 applications, including opening carry-over backlog and applications received during the reporting period. The generation process includes designed seasonality, rework loops, cancellations and deliberate data-quality issues. Results are shaped by those assumptions and cannot establish real-world frequency or causation.

## 3. KPI populations and eligibility
The dataset contains 2,167 completed applications, while 2,162 valid completed cycles are used for cycle-time analysis after excluding five impossible completion sequences. These populations must not be interchanged without explanation.
The 19.9% rework rate uses 530 applications with qualifying rework and 2,665 eligible applications. The 571 qualifying rework events are events, not distinct applications. The 35-calendar-day SLA and all eligibility rules must remain consistent across SQL, Excel and Power BI.

## 4. Data quality
The reported validation suite passed 12/12 data-quality reconciliation checks, 20/20 scalar validation checks and 12/12 monthly backlog reconciliation checks. These checks demonstrate consistency against expected synthetic-data counts and documented rules, not freedom from every possible error.
The total is **586 issue instances** across issue categories. It is not a distinct-record count because a record may contain more than one issue.

## 5. Bottleneck analysis
Finance Approval ranks first in the supplied composite bottleneck analysis. This is a prioritisation signal, not proof that the stage is the sole or causal source of the overall SLA shortfall. A live investigation would require operational observation, stakeholder interviews and validated system timestamps.

## 6. Rework effort
Estimated rework minutes are effort proxies, not verified timesheets, payroll costs or measured labour hours. Rework-driver data includes multiple dimensions; summing across dimensions can count the same events multiple times. Interpret driver rankings within the selected dimension.

## 7. Capacity and workload
Capacity hours, complexity points, stage episodes and owner-level workload indicators are distinct units. Available capacity is not necessarily productive time; complexity points are not labour hours; stage episodes are not distinct applications; and owner comparisons may be affected by role, FTE allocation and work mix. These metrics do not prove employee utilisation or that a team is over capacity.

## 8. Excel intervention and financial model
The Phase 4 Excel model compares options under conservative, base and optimistic assumptions. Throughput, staffing, demand gaps and first-year/recurring cost outputs are modelled estimates, not realised savings or committed budgets. Validate assumptions, sensitivity calculations, double-counting checks and recommendation logic before a management decision. Do not treat freed capacity as cash savings unless a cash cost changes.

## 9. Proposed future-state operating model
The future-state map, RACI and SOP are proposed designs, not approved policies or implemented controls. Role authority, approval permissions, escalation thresholds, retention rules and control ownership require stakeholder approval before live deployment.

## 10. Power BI reporting scope
Four Power BI pages have been implemented: Executive Report, Process Bottlenecks, Quality & Rework, and Capacity & Workload. The planned fifth page, Intervention Scenarios, has not been built. Options A–D and scenario cases are evaluated in the Excel decision model; no interactive Power BI scenario comparison is claimed. README, executive summary and portfolio descriptions should consistently state the four-page scope.

## 11. Future validation
A live implementation would require stakeholder validation, source-system and timestamp checks, recalculation using actual records, approval of KPI definitions and SLA rules, validation of cost/staffing assumptions, a controlled pilot with pre-agreed success criteria, and post-pilot comparison against a suitable baseline.

## 12. Responsible interpretation
The synthetic baseline identifies areas worth investigating and interventions worth evaluating. It does not prove that any proposed intervention has delivered a business benefit.


## Documentation change log

- **2026-10-17:** Confirmed four-page Power BI scope; clarified that the 586 total represents issue instances across categories, not unique records.
