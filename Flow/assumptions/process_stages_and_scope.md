# FLOW: Process Stages and Scope
Company: Northstar Cloud Services (fictional B2B SaaS). All data is synthetic.

## Decision question
Can Northstar complete at least 240 onboardings per month with a redesigned process? Is extra staffing needed? Which option has the best risk-adjusted economics?

## Planning hypotheses (to be tested, not reproduced)
45-day average cycle time, 12% rework, about 200 completions/month capacity, about 240/month demand, about INR 8,000 cost per completion.

## Stages
| # | Stage | Owner team | Entry criterion | Exit criterion |
|---|---|---|---|---|
| 1 | Intake & Submission | Sales | Closed-won deal; onboarding request created | Intake form submitted with all required fields |
| 2 | Handoff Acceptance | RevOps | Intake form submitted | Required fields and documents validated, or returned to Sales |
| 3 | Contract & Legal Review | Legal | Handoff accepted | Mandatory contract and risk checks cleared |
| 4 | Finance Approval | Finance | Legal cleared (standard-risk cases may run in parallel in the future state) | Credit check passed and billing set up |
| 5 | Implementation Setup | Implementation | Finance approved | Configuration and data migration complete |
| 6 | Go-live Readiness | Implementation | Setup complete | Training and customer acceptance done |
| 7 | Activation Handoff | Customer Success | Go-live readiness confirmed | Customer Success accepts the account (= Completed) |

## Allowed loops (each creates a rework event)
- Handoff Acceptance -> Intake & Submission (missing or incorrect information)
- Legal -> Intake & Submission (missing contract documents)
- Finance -> Handoff Acceptance (credit or billing details incorrect)
- Implementation Setup -> Handoff Acceptance (requirements unclear)

## Terminal statuses
Completed (passed stage 7) | Cancelled (customer withdrew or deal lost) | Open (in progress at the cutoff)

## Time concepts
- Calendar time: elapsed days, including weekends and holidays (primary measure).
- Working time: Mon-Fri excluding holiday_flag days (secondary measure).
- Queue time: stage entered_at to the first task assigned_at in that stage.
- In-progress time: task assigned_at to completed_at. This is a proxy for active work because hands-on minutes are not measured. Hands-on effort is only known for rework (estimated_minutes).

## In scope
Process mapping, stage cycle-time analysis, backlog and throughput, rework analysis, capacity and cost modelling, workflow redesign, KPI definitions, management dashboard, optional HubSpot demo.

## Out of scope
Live customer data, production CRM deployment, real integrations, actual staffing changes, any claim of realised savings.

## Intervention options to be evaluated
A: No change | B: Process redesign and workflow controls | C: Additional staffing | D: Redesign plus targeted staffing