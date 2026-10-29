# FLOW: Data Generation Assumptions
Company: Northstar Cloud Services (fictional B2B SaaS). **All data is synthetic.** No real employer, customer or employee data is used.

## 1. Purpose
This file lists how the data was built, which mechanisms were planted, and the expected direction of each. It does not contain results. The analysis must find the real values. The planning hypotheses (45-day cycle, 12% rework, ~200 capacity, ~240 demand, ~INR 8,000 per completion) were not used as targets; inputs were chosen for plausible B2B SaaS onboarding levels, so the hypotheses informed order of magnitude only.

## 2. Scope of the data
| Item | Assumption |
|---|---|
| Analysis period | 1 Oct 2025 to 30 Sep 2026 (extract cutoff 30 Sep 2026, end of day) |
| Warm-up | Simulation starts 1 Aug 2025 so the system is not empty at period start. Applications that were still open on 1 Oct 2025 are kept as carry-over (opening backlog). Applications closed before 1 Oct 2025 are dropped. |
| Volume | About 2,700 applications, about 18,000 stage entries, about 21,000 tasks, about 600 rework events, 31 owners |
| Calendar table | 1 Aug 2025 to 30 Sep 2026 (covers carry-over stage dates). Holidays are illustrative. |
| Working time | Mon-Fri excluding holidays, 09:00-18:00. Applications are created on working days only. |
| Truncation | Anything after the cutoff is not recorded. Items in flight have null exit/completion timestamps. |

## 3. How the process was simulated
- Seven stages in the order defined in `process_stages_and_scope.md`, with four allowed loops and a maximum of three loops per application.
- Each owner behaves as one worker in a first-in-first-out queue for their team. An owner works on one item at a time. The owner's hours per day come from `monthly_capacity_hours / 21`, and each owner has a small hidden speed variation (about +/-7%).
- Each stage visit has hands-on effort (hours), scaled by complexity (Low 0.6x, Medium 1.0x, High 1.9x) with random variation.
- After the work, a stage may add external waiting time (customer, counterparty or credit-agency response). External waiting does not occupy an owner. Its mean is scaled by complexity (Low 0.7x, Medium 1.0x, High 1.8x) and is 20% shorter for Urgent priority.
- Rework passes (after a loop) need half the effort and half the external wait.
- Cancellation chance per stage exit rises with how long the application waited in that stage.
- Priority is descriptive plus the Urgent wait effect above. It does not change queue order.

## 4. Planted mechanisms and expected direction
| ID | Mechanism | How it is built | Expected direction in analysis |
|---|---|---|---|
| M1 | Demand seasonality and growth | Monthly demand = base x seasonal factor x upward trend. Peaks in Mar 2026 and Aug-Sep 2026, low in Jan 2026. | Received volume rises through the year with spikes in Mar and Sep |
| M2 | Finance Approval capacity constraint | Finance has the least spare capacity relative to its stage load. Demand exceeds it in peak months. | Finance queue time and WIP grow in high-demand months and partly recover in Apr-May. This should rank as the leading bottleneck. |
| M3 | Long duration that is not a queue (decoy) | Legal and Implementation have long external waits but enough staff | Long stage durations with near-zero queue time. They should NOT rank as the bottleneck on duration alone. |
| M4 | Implementation capacity change | One specialist joins on 1 Feb 2026 and one leaves on 31 Aug 2026 | Slightly more Implementation pressure in Aug-Sep 2026 than earlier |
| M5 | Incomplete submissions by type | Custom Integration applications are returned at Handoff Acceptance far more often than other types. Partner Referral adds a small extra rate. | Higher return/rework rate for Custom Integration at Handoff |
| M6 | New sales rep context trap | S08 joins on 15 Jan 2026 and has about double the intake error rate | S08 looks poor in a raw comparison. It must be judged with tenure and volume context. |
| M7 | Type-specific returns downstream | Enterprise Multi-Entity returns more at Legal, Reseller/Partner at Finance (billing), Custom Integration at Implementation (requirements) | Rework drivers differ by type and handoff |
| M8 | Complexity effect | Effort and external waits scale with complexity band | High complexity has longer cycle time and more variation |
| M9 | Delay-driven cancellation | Cancellation hazard rises with long waits | Cancelled cases skew to longer waits, and "Customer withdrew - delay" appears |
| M10 | Owner capacity differences | Part-time owners (FTE 0.5-0.8), a new joiner and a leaver | Owner workload must be read with capacity and active-period context |

## 5. Key inputs
**Demand:** base about 212 per month, seasonal factors Oct .95, Nov .95, Dec 1.10, Jan .85, Feb .95, Mar 1.20, Apr .90, May .95, Jun 1.00, Jul 1.00, Aug 1.05, Sep 1.15, multiplied by a trend rising from 0.85 to 1.15 across the 12 months. Arrivals are Poisson per working day.

**Owner hours per month per 1.0 FTE:** Sales 75, RevOps 120, Legal 150, Finance 95, Implementation 180, Customer Success 90. Hours are already scaled by FTE in `owners.monthly_capacity_hours`.

**Cost per hour (INR, base before +/-10-15% variation):** Sales 720, RevOps 580, Legal 1,050, Finance 680, Implementation 640, Customer Success 520.

## 6. Intentional data-quality problems
Each is flagged and handled transparently. None is silently fixed.
| ID | Table | Problem | Handling rule |
|---|---|---|---|
| Q1 | stage_history | exited_at earlier than entered_at | Flag, exclude from duration statistics, report count |
| Q2 | stage_history | owner_id missing on a worked stage | Flag, keep in stage metrics, exclude from owner workload |
| Q3 | stage_history | Duplicate-looking rows with new stage_event_id | Detect on application + stage + entered_at + exited_at, keep the lowest ID |
| Q4 | applications | final_status variants ("Complete", "completed", "Canceled") | Map to the standard values in a cleaned view |
| Q5 | applications | Completed but completed_at missing | Flag, use closed_at as fallback, report count |
| Q6 | applications | completed_at earlier than the final stage exit | Flag as impossible sequence, exclude from cycle-time statistics |
| Q7 | tasks | Completed task with no assigned_at | Flag, exclude from queue-time statistics |
| Q8 | tasks | due_at earlier than created_at | Flag, exclude from overdue measures |
| Q9 | rework_events | reason_code in inconsistent case | Standardise in a cleaned view |
| Q10 | rework_events | estimated_minutes = 0 | Not qualifying rework under KPI definitions |
| Q11 | rework_events | resolution_status = Invalid | Excluded from rework rate per KPI definitions |
| Q12 | rework_events | Orphan application_id | Flag, exclude from joins, report count |

Exact counts are written to `generation_summary.txt` on each run.

## 7. Simplifications and limitations
- Queue order is first-in-first-out. Priority does not jump the queue.
- Owners handle one item at a time. Real staff multitask.
- `assigned_at` means the moment an owner picked up the task (pull-based assignment). Queue time is created_at to assigned_at.
- A task's `completed_at` includes external waiting, so assigned-to-completed is "in-progress time", not hands-on time. Hands-on effort is only measured for rework (`estimated_minutes`).
- External waits ignore weekends and holidays on the customer side.
- Cost rates and effort hours are plausible assumptions, not benchmarks.
- The number of loops per application is capped at three.

## 8. Reproducibility
Fixed random seed (20261013) in `generate_flow_data.py`. Library versions can change random streams slightly, so exact counts may differ by small amounts on another setup. Always use the counts from your own `generation_summary.txt`.